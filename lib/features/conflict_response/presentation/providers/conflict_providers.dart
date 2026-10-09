import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/models/alert_status_change.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/community_report.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/models/response_assignment.dart';
import '../../../../shared/models/risk_zone.dart';
import '../../../../shared/models/tracked_animal.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/repositories/conflict_repository.dart';
import '../../data/datasources/conflict_local_data_source.dart';
import '../../data/notification/simulated_notification_service.dart';
import '../../data/repositories/drift_conflict_repository.dart';
import '../../data/repositories/firestore_conflict_repository.dart';
import '../../domain/conflict_config.dart';
import '../../domain/notification_service.dart';

/// Simulated notification service (swap for an FCM-backed one when available).
final notificationServiceProvider = Provider<NotificationService>(
  (_) => SimulatedNotificationService(),
);

/// Configurable acknowledgement threshold in minutes for automatic overdue escalation.
/// Defaults to 15 minutes as per spec, but can be set to e.g. 1 minute for rapid demo/testing.
class AcknowledgementThresholdNotifier extends Notifier<int> {
  @override
  int build() => 15;

  void setThreshold(int minutes) => state = minutes;
}

final acknowledgementThresholdMinutesProvider =
    NotifierProvider<AcknowledgementThresholdNotifier, int>(
  AcknowledgementThresholdNotifier.new,
);

/// Tunable configuration derived from the acknowledgement threshold provider.
final conflictConfigProvider = Provider<ConflictConfig>((ref) {
  final minutes = ref.watch(acknowledgementThresholdMinutesProvider);
  return ConflictConfig(
    readingFreshness: const Duration(minutes: 30),
    acknowledgementTimeout: Duration(minutes: minutes),
  );
});

/// Local data source backed by Drift/SQLite for UC03 persistence.
final conflictLocalDataSourceProvider = Provider<ConflictLocalDataSource>((ref) {
  return ConflictLocalDataSource(ref.watch(appDatabaseProvider));
});

/// UC03 repository. Uses Firestore when Firebase is configured/initialized;
/// otherwise uses DriftConflictRepository so UC03 data (alerts, readings, assignments,
/// status history, community reports) survives app restart, matching UC01/UC02.
final conflictRepositoryProvider = Provider<ConflictRepository>((ref) {
  final notifications = ref.watch(notificationServiceProvider);
  final config = ref.watch(conflictConfigProvider);
  return ref.watch(firebaseReadyProvider)
      ? FirestoreConflictRepository(
          firestore: FirebaseFirestore.instance,
          notificationService: notifications,
          config: config,
        )
      : DriftConflictRepository(
          localDataSource: ref.watch(conflictLocalDataSourceProvider),
          notificationService: notifications,
          config: config,
        );
});

// --- Read providers ---------------------------------------------------------

final riskAlertsProvider =
    FutureProvider.family<List<WildlifeRiskAlert>, String>((ref, parkId) {
  return ref.watch(conflictRepositoryProvider).getAlerts(parkId);
});

final alertProvider =
    FutureProvider.family<WildlifeRiskAlert?, String>((ref, alertId) {
  return ref.watch(conflictRepositoryProvider).getAlert(alertId);
});

final riskZonesProvider =
    FutureProvider.family<List<RiskZone>, String>((ref, parkId) {
  return ref.watch(conflictRepositoryProvider).getRiskZones(parkId);
});

final trackedAnimalsProvider = FutureProvider<List<TrackedAnimal>>((ref) {
  return ref.watch(conflictRepositoryProvider).getTrackedAnimals();
});

final communityReportsProvider =
    FutureProvider.family<List<CommunityReport>, String>((ref, parkId) {
  return ref.watch(conflictRepositoryProvider).getCommunityReports(parkId);
});

final availableRespondersProvider =
    FutureProvider.family<List<AppUser>, String>((ref, parkId) {
  return ref.watch(conflictRepositoryProvider).getAvailableResponders(parkId);
});

final assignmentsForAlertProvider =
    FutureProvider.family<List<ResponseAssignment>, String>((ref, alertId) {
  return ref.watch(conflictRepositoryProvider).getAssignmentsForAlert(alertId);
});

final activeAssignmentProvider =
    FutureProvider.family<ResponseAssignment?, String>((ref, alertId) {
  return ref.watch(conflictRepositoryProvider).getActiveAssignment(alertId);
});

final alertStatusHistoryProvider =
    FutureProvider.family<List<AlertStatusChange>, String>((ref, alertId) {
  return ref.watch(conflictRepositoryProvider).getStatusHistory(alertId);
});

// --- Mutation controller ----------------------------------------------------

/// Drives every UC03 write. Each method calls the repository, refreshes the
/// affected read providers, and rethrows domain errors so the UI can surface a
/// message (nothing is swallowed, nothing crashes).
final conflictControllerProvider =
    AsyncNotifierProvider<ConflictController, void>(ConflictController.new);

class ConflictController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  ConflictRepository get _repo => ref.read(conflictRepositoryProvider);

  Future<T> _mutate<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      final result = await action();
      _refreshAll();
      state = const AsyncData(null);
      return result;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  void _refreshAll() {
    ref.invalidate(riskAlertsProvider);
    ref.invalidate(alertProvider);
    ref.invalidate(communityReportsProvider);
    ref.invalidate(availableRespondersProvider);
    ref.invalidate(assignmentsForAlertProvider);
    ref.invalidate(activeAssignmentProvider);
    ref.invalidate(alertStatusHistoryProvider);
  }

  // Trigger A – simulate a collar reading through the real domain pipeline.
  Future<WildlifeRiskAlert?> simulateCollarReading({
    required String animalId,
    required double latitude,
    required double longitude,
  }) {
    final now = DateTime.now();
    final reading = LocationReading.create(
      animalId: animalId,
      latitude: latitude,
      longitude: longitude,
      observedAt: now,
      receivedAt: now,
    );
    return _mutate(() => _repo.processLocationReading(reading));
  }

  // Submit a community conflict report (Channel APP or simulated SMS).
  Future<CommunityReport> submitCommunityReport({
    required String parkId,
    required String description,
    required double latitude,
    required double longitude,
    String channel = 'APP',
  }) {
    final report = CommunityReport.create(
      parkId: parkId,
      description: description,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
      channel: channel,
    );
    return _mutate(() => _repo.submitCommunityReport(report));
  }

  // Trigger B – verify a community report, then run it through the same pipeline.
  Future<WildlifeRiskAlert?> verifyAndProcessCommunityReport(
    String reportId,
  ) {
    return _mutate(() async {
      final me = ref.read(currentUserProvider);
      final verified = await _repo.verifyCommunityReport(
        reportId: reportId,
        verifiedBy: me.id,
      );
      return _repo.processCommunityReport(verified);
    });
  }

  Future<ResponseAssignment> assignResponder({
    required String alertId,
    required String responderId,
  }) {
    return _mutate(() {
      final me = ref.read(currentUserProvider);
      return _repo.assignResponder(
        alertId: alertId,
        responderId: responderId,
        assignedBy: me.id,
      );
    });
  }

  Future<ResponseAssignment> retryNotificationDelivery(String assignmentId) =>
      _mutate(() => _repo.retryNotificationDelivery(assignmentId));

  Future<ResponseAssignment> acknowledge(String assignmentId) {
    return _mutate(() {
      final me = ref.read(currentUserProvider);
      return _repo.acknowledgeAssignment(
        assignmentId: assignmentId,
        responderId: me.id,
      );
    });
  }

  Future<ResponseAssignment> startResponse(String assignmentId) =>
      _mutate(() => _repo.startResponse(assignmentId));

  Future<ResponseAssignment> updateStatus({
    required String assignmentId,
    required String note,
  }) =>
      _mutate(() => _repo.updateResponseStatus(
            assignmentId: assignmentId,
            statusNote: note,
          ));

  Future<ResponseAssignment> recordOutcome({
    required String assignmentId,
    required String outcome,
  }) =>
      _mutate(() => _repo.recordOutcome(
            assignmentId: assignmentId,
            outcome: outcome,
          ));

  Future<WildlifeRiskAlert> resolveAlert(String alertId) =>
      _mutate(() => _repo.resolveAlert(alertId));

  Future<List<WildlifeRiskAlert>> checkAndEscalateOverdue(String parkId) {
    final config = ref.read(conflictConfigProvider);
    return _mutate(() => _repo.checkAndEscalateOverdueAlerts(
          parkId: parkId,
          config: config,
        ));
  }
}

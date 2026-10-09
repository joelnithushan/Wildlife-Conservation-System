import '../../../../core/enums/app_enums.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../../../shared/models/alert_status_change.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/community_report.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/models/response_assignment.dart';
import '../../../../shared/models/risk_zone.dart';
import '../../../../shared/models/tracked_animal.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../../../shared/repositories/conflict_repository.dart';
import '../../domain/acknowledgement_monitor.dart';
import '../../domain/alert_rules.dart';
import '../../domain/conflict_config.dart';
import '../../domain/notification_service.dart';
import '../../domain/reading_validation.dart';
import '../../domain/usecases/process_location_reading.dart';
import '../datasources/conflict_local_data_source.dart';

/// Offline-first [ConflictRepository] backed by Drift/SQLite.
/// Persists alerts, readings, assignments, status history, and community reports
/// so all UC03 data survives app restart, exactly matching UC01/UC02 storage approach.
class DriftConflictRepository implements ConflictRepository {
  DriftConflictRepository({
    required ConflictLocalDataSource localDataSource,
    NotificationService? notificationService,
    List<RiskZone>? riskZones,
    List<TrackedAnimal>? animals,
    List<AppUser>? responders,
    ConflictConfig config = ConflictConfig.defaults,
    DateTime Function()? now,
  })  : _local = localDataSource,
        _notifications = notificationService ?? _DefaultNotifier(),
        _config = config,
        _now = now ?? DateTime.now,
        _zones = List.of(riskZones ?? DemoData.riskZones),
        _animals = List.of(animals ?? DemoData.trackedAnimals),
        _responders = List.of(responders ?? DemoData.conflictResponders) {
    _processor = ProcessLocationReading(config: _config);
  }

  final ConflictLocalDataSource _local;
  final NotificationService _notifications;
  final ConflictConfig _config;
  final DateTime Function() _now;
  final List<RiskZone> _zones;
  final List<TrackedAnimal> _animals;
  final List<AppUser> _responders;

  late final ProcessLocationReading _processor;
  final Set<String> _seenReadingIds = {};
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    // Check if alerts table is empty, seed demo data if needed.
    final existingAlerts = await _local.getAllAlerts();
    if (existingAlerts.isEmpty) {
      final now = _now();
      for (final a in DemoData.seededAlerts(now)) {
        await _local.upsertAlert(a);
        await _local.saveStatusChange(AlertStatusChange.create(
          alertId: a.id,
          fromStatus: null,
          toStatus: a.status,
          changedBy: 'System (Seed)',
          reason: 'Initial alert creation',
          timestamp: a.createdAt,
        ));
      }
      for (final r in DemoData.communityReports) {
        await _local.upsertCommunityReport(r);
      }
    }
  }

  // --- Triggers -------------------------------------------------------------

  @override
  Future<WildlifeRiskAlert?> processLocationReading(
    LocationReading reading,
  ) async {
    await _ensureInitialized();
    final existingAlerts = await _local.getAllAlerts();

    final result = _processor.call(
      reading: reading,
      activeZones: _zones,
      existingAlerts: existingAlerts,
      now: _now(),
      seenReadingIds: _seenReadingIds,
    );

    if (result.outcome == ProcessOutcome.rejected) {
      throw ConflictException(result.rejection.message);
    }

    _seenReadingIds.add(reading.id);
    await _local.saveReading(reading);

    if (result.alert != null) {
      final isNew = await _local.getAlertById(result.alert!.id) == null;
      await _local.upsertAlert(result.alert!);
      if (isNew) {
        await _local.saveStatusChange(AlertStatusChange.create(
          alertId: result.alert!.id,
          fromStatus: null,
          toStatus: AlertStatus.newAlert,
          changedBy: 'System (Collar Reading)',
          reason: 'Alert raised from animal collar GPS entering risk zone',
          timestamp: _now(),
        ));
      }
    }
    return result.alert;
  }

  @override
  Future<WildlifeRiskAlert?> processCommunityReport(
    CommunityReport report,
  ) async {
    if (!report.verified) return null;
    await _ensureInitialized();
    final existingAlerts = await _local.getAllAlerts();

    final result = _processor.fromCommunityPoint(
      parkId: report.parkId,
      latitude: report.latitude,
      longitude: report.longitude,
      activeZones: _zones,
      existingAlerts: existingAlerts,
      now: _now(),
    );

    if (result.outcome == ProcessOutcome.rejected) {
      throw ConflictException(result.rejection.message);
    }

    if (result.alert != null) {
      final isNew = await _local.getAlertById(result.alert!.id) == null;
      await _local.upsertAlert(result.alert!);
      if (isNew) {
        await _local.saveStatusChange(AlertStatusChange.create(
          alertId: result.alert!.id,
          fromStatus: null,
          toStatus: AlertStatus.newAlert,
          changedBy: report.verifiedBy ?? 'CLO',
          reason: 'Alert raised from verified community sighting',
          timestamp: _now(),
        ));
      }
    }
    return result.alert;
  }

  // --- Reference/read data --------------------------------------------------

  @override
  Future<List<WildlifeRiskAlert>> getAlerts(String parkId) async {
    await _ensureInitialized();
    return _local.getAlertsByPark(parkId);
  }

  @override
  Future<WildlifeRiskAlert?> getAlert(String id) async {
    await _ensureInitialized();
    return _local.getAlertById(id);
  }

  @override
  Future<List<RiskZone>> getRiskZones(String parkId) async =>
      _zones.where((z) => z.parkId == parkId).toList();

  @override
  Future<List<TrackedAnimal>> getTrackedAnimals() async => List.of(_animals);

  // --- Community reports ----------------------------------------------------

  @override
  Future<List<CommunityReport>> getCommunityReports(String parkId) async {
    await _ensureInitialized();
    return _local.getCommunityReportsByPark(parkId);
  }

  @override
  Future<CommunityReport> submitCommunityReport(CommunityReport report) async {
    await _ensureInitialized();
    await _local.upsertCommunityReport(report);
    return report;
  }

  @override
  Future<CommunityReport> verifyCommunityReport({
    required String reportId,
    required String verifiedBy,
  }) async {
    await _ensureInitialized();
    final report = await _local.getCommunityReportById(reportId);
    if (report == null) {
      throw const ConflictException('Community report not found.');
    }
    final updated = report.copyWith(verified: true, verifiedBy: verifiedBy);
    await _local.upsertCommunityReport(updated);
    return updated;
  }

  // --- Responders & assignments ---------------------------------------------

  @override
  Future<List<AppUser>> getAvailableResponders(String parkId) async {
    return _responders
        .where((u) => u.parkId == parkId && u.isResponder && u.isAvailable)
        .toList();
  }

  @override
  Future<List<ResponseAssignment>> getAssignmentsForAlert(String alertId) async {
    await _ensureInitialized();
    return _local.getAssignmentsForAlert(alertId);
  }

  @override
  Future<ResponseAssignment?> getActiveAssignment(String alertId) async {
    await _ensureInitialized();
    return _local.getActiveAssignment(alertId);
  }

  @override
  Future<ResponseAssignment?> getAssignment(String assignmentId) async {
    await _ensureInitialized();
    return _local.getAssignmentById(assignmentId);
  }

  @override
  Future<ResponseAssignment> assignResponder({
    required String alertId,
    required String responderId,
    required String assignedBy,
  }) async {
    await _ensureInitialized();
    final alert = await _local.getAlertById(alertId);
    if (alert == null) throw const ConflictException('Alert not found.');
    if (alert.status == AlertStatus.resolved) {
      throw const ConflictException('Cannot assign: alert is resolved.');
    }

    final active = await getActiveAssignment(alertId);
    if (alert.status == AlertStatus.acknowledged ||
        alert.status == AlertStatus.responseInProgress) {
      throw const ConflictException(
        'Alert already has an active responder in progress.',
      );
    }

    final available = await getAvailableResponders(alert.parkId);
    if (available.isEmpty) {
      throw const ConflictException('No responder available.');
    }
    final responder =
        available.where((r) => r.id == responderId).firstOrNull;
    if (responder == null) {
      throw const ConflictException(
        'Assignment conflict: responder is no longer available.',
      );
    }

    final assignment = ResponseAssignment.create(
      alertId: alertId,
      responderId: responderId,
      responderRole: responder.role == UserRole.ranger
          ? ResponderRole.ranger
          : ResponderRole.communityLiaisonOfficer,
      assignedBy: assignedBy,
      assignedAt: _now(),
    );
    await _local.upsertAssignment(assignment);

    if (alert.status == AlertStatus.newAlert) {
      final updated = alert.copyWith(status: AlertStatus.assigned);
      await _local.upsertAlert(updated);
      await _local.saveStatusChange(AlertStatusChange.create(
        alertId: alertId,
        fromStatus: AlertStatus.newAlert,
        toStatus: AlertStatus.assigned,
        changedBy: assignedBy,
        reason: 'Assigned to responder $responderId',
        timestamp: _now(),
      ));
    } else {
      await _local.saveStatusChange(AlertStatusChange.create(
        alertId: alertId,
        fromStatus: alert.status,
        toStatus: alert.status,
        changedBy: assignedBy,
        reason: 'Reassigned to responder $responderId',
        timestamp: _now(),
      ));
    }
    assert(active == null || alert.status == AlertStatus.assigned);

    final result = await _notifications.notifyAssignment(
      assignmentId: assignment.id,
      responderId: responderId,
      title: 'New response assignment',
      body: 'You have been assigned to alert ${alert.id}.',
    );
    final delivered = assignment.copyWith(
      deliveryState: result.state,
      deliveredAt: result.isDelivered ? _now() : null,
    );
    await _local.upsertAssignment(delivered);
    return delivered;
  }

  @override
  Future<ResponseAssignment> retryNotificationDelivery(
    String assignmentId,
  ) async {
    await _ensureInitialized();
    final assignment = await _local.getAssignmentById(assignmentId);
    if (assignment == null) {
      throw const ConflictException('Assignment not found.');
    }
    final alert = await _local.getAlertById(assignment.alertId);
    final result = await _notifications.notifyAssignment(
      assignmentId: assignment.id,
      responderId: assignment.responderId,
      title: 'Response assignment (retry)',
      body: 'You have been assigned to alert ${alert?.id ?? assignment.alertId}.',
    );
    final retried = assignment.copyWith(
      deliveryState: result.state,
      deliveredAt: result.isDelivered ? _now() : assignment.deliveredAt,
    );
    await _local.upsertAssignment(retried);
    return retried;
  }

  @override
  Future<ResponseAssignment> acknowledgeAssignment({
    required String assignmentId,
    required String responderId,
  }) async {
    await _ensureInitialized();
    final assignment = await _local.getAssignmentById(assignmentId);
    if (assignment == null) {
      throw const ConflictException('Assignment not found.');
    }
    if (assignment.responderId != responderId) {
      throw const ConflictException(
        'Only the assigned responder can acknowledge this assignment.',
      );
    }
    if (assignment.acknowledgedAt != null) {
      throw const ConflictException('Assignment already acknowledged.');
    }
    final active = await getActiveAssignment(assignment.alertId);
    if (active?.id != assignmentId) {
      throw const ConflictException(
        'This assignment has been superseded by a reassignment.',
      );
    }

    final alert = await _local.getAlertById(assignment.alertId);
    if (alert == null) throw const ConflictException('Alert not found.');
    AlertRules.assertTransition(alert.status, AlertStatus.acknowledged);

    final updatedAlert = alert.copyWith(status: AlertStatus.acknowledged);
    await _local.upsertAlert(updatedAlert);
    await _local.saveStatusChange(AlertStatusChange.create(
      alertId: alert.id,
      fromStatus: alert.status,
      toStatus: AlertStatus.acknowledged,
      changedBy: responderId,
      reason: 'Acknowledged by assigned responder',
      timestamp: _now(),
    ));

    final updatedAssignment = assignment.copyWith(acknowledgedAt: _now());
    await _local.upsertAssignment(updatedAssignment);
    return updatedAssignment;
  }

  @override
  Future<ResponseAssignment> startResponse(String assignmentId) async {
    await _ensureInitialized();
    final assignment = await _local.getAssignmentById(assignmentId);
    if (assignment == null) {
      throw const ConflictException('Assignment not found.');
    }
    if (assignment.acknowledgedAt == null) {
      throw const ConflictException(
        'Cannot start response before acknowledgement.',
      );
    }
    final alert = await _local.getAlertById(assignment.alertId);
    if (alert == null) throw const ConflictException('Alert not found.');
    AlertRules.assertTransition(alert.status, AlertStatus.responseInProgress);

    final updatedAlert = alert.copyWith(status: AlertStatus.responseInProgress);
    await _local.upsertAlert(updatedAlert);
    await _local.saveStatusChange(AlertStatusChange.create(
      alertId: alert.id,
      fromStatus: alert.status,
      toStatus: AlertStatus.responseInProgress,
      changedBy: assignment.responderId,
      reason: 'Response started on-site by responder',
      timestamp: _now(),
    ));

    final updatedAssignment = assignment.copyWith(startedAt: _now());
    await _local.upsertAssignment(updatedAssignment);
    return updatedAssignment;
  }

  @override
  Future<ResponseAssignment> updateResponseStatus({
    required String assignmentId,
    required String statusNote,
  }) async {
    await _ensureInitialized();
    final assignment = await _local.getAssignmentById(assignmentId);
    if (assignment == null) {
      throw const ConflictException('Assignment not found.');
    }
    if (assignment.startedAt == null) {
      throw const ConflictException(
        'Cannot record a status note before the response starts.',
      );
    }
    final updated = assignment.copyWith(statusNote: statusNote);
    await _local.upsertAssignment(updated);
    return updated;
  }

  @override
  Future<ResponseAssignment> recordOutcome({
    required String assignmentId,
    required String outcome,
  }) async {
    if (outcome.trim().isEmpty) {
      throw const ConflictException('Outcome cannot be empty.');
    }
    await _ensureInitialized();
    final assignment = await _local.getAssignmentById(assignmentId);
    if (assignment == null) {
      throw const ConflictException('Assignment not found.');
    }
    if (assignment.startedAt == null) {
      throw const ConflictException(
        'Cannot record an outcome before the response starts.',
      );
    }
    final updated = assignment.copyWith(
      outcome: outcome,
      completedAt: _now(),
    );
    await _local.upsertAssignment(updated);
    return updated;
  }

  @override
  Future<WildlifeRiskAlert> resolveAlert(String alertId) async {
    await _ensureInitialized();
    final alert = await _local.getAlertById(alertId);
    if (alert == null) throw const ConflictException('Alert not found.');
    final assignments = await getAssignmentsForAlert(alertId);
    AlertRules.assertResolvable(alert, assignments);
    final resolved = alert.copyWith(
      status: AlertStatus.resolved,
      resolvedAt: _now(),
    );
    await _local.upsertAlert(resolved);
    await _local.saveStatusChange(AlertStatusChange.create(
      alertId: alertId,
      fromStatus: alert.status,
      toStatus: AlertStatus.resolved,
      changedBy: 'Park Manager',
      reason: 'Alert resolved by Park Manager after outcome verification',
      timestamp: _now(),
    ));
    return resolved;
  }

  @override
  Future<List<WildlifeRiskAlert>> checkAndEscalateOverdueAlerts({
    required String parkId,
    ConflictConfig? config,
  }) async {
    await _ensureInitialized();
    final cfg = config ?? _config;
    final overdueAlerts = <WildlifeRiskAlert>[];
    final alerts = await _local.getAlertsByPark(parkId);
    for (final alert in alerts) {
      if (alert.status == AlertStatus.assigned) {
        final active = await getActiveAssignment(alert.id);
        if (active != null &&
            AcknowledgementMonitor.isOverdue(active, now: _now(), config: cfg)) {
          overdueAlerts.add(alert);
          await _local.saveStatusChange(AlertStatusChange.create(
            alertId: alert.id,
            fromStatus: alert.status,
            toStatus: alert.status,
            changedBy: 'System Escalation Monitor',
            reason:
                'Automatic overdue escalation: Acknowledgement timeout exceeded (> ${cfg.acknowledgementTimeout.inMinutes}m)',
            timestamp: _now(),
          ));
        }
      }
    }
    return overdueAlerts;
  }

  @override
  Future<List<AlertStatusChange>> getStatusHistory(String alertId) async {
    await _ensureInitialized();
    return _local.getStatusHistory(alertId);
  }
}

class _DefaultNotifier implements NotificationService {
  @override
  Future<NotificationResult> notifyAssignment({
    required String assignmentId,
    required String responderId,
    required String title,
    required String body,
  }) async =>
      const NotificationResult(DeliveryState.delivered);
}

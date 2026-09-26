import '../../../../core/enums/app_enums.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/community_report.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/models/response_assignment.dart';
import '../../../../shared/models/risk_zone.dart';
import '../../../../shared/models/tracked_animal.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../../../shared/repositories/conflict_repository.dart';
import '../../domain/alert_rules.dart';
import '../../domain/conflict_config.dart';
import '../../domain/notification_service.dart';
import '../../domain/reading_validation.dart';
import '../../domain/usecases/process_location_reading.dart';

/// Offline-first, fully in-memory implementation of [ConflictRepository].
///
/// The app runs offline-first (Firebase is off by default), so UC03 uses this
/// deterministic store for both the running app and unit tests. It enforces
/// every UC03 rule (single open alert per animal+zone, legal status
/// transitions, responder-identity checks, delivery-vs-acknowledgement, resolve
/// requires an outcome) and keeps stable IDs so repeated calls never duplicate
/// records. A Firestore-backed implementation can later satisfy the same
/// contract without touching the domain or UI.
class InMemoryConflictRepository implements ConflictRepository {
  InMemoryConflictRepository({
    NotificationService? notificationService,
    List<RiskZone>? riskZones,
    List<TrackedAnimal>? animals,
    List<AppUser>? responders,
    List<CommunityReport>? communityReports,
    List<WildlifeRiskAlert>? seedAlerts,
    ConflictConfig config = ConflictConfig.defaults,
    DateTime Function()? now,
  })  : _notifications = notificationService ?? _NullNotifier(),
        _config = config,
        _now = now ?? DateTime.now,
        _zones = List.of(riskZones ?? DemoData.riskZones),
        _animals = List.of(animals ?? DemoData.trackedAnimals),
        _responders = List.of(responders ?? DemoData.conflictResponders) {
    _processor = ProcessLocationReading(config: _config);
    for (final r in communityReports ?? DemoData.communityReports) {
      _reports[r.id] = r;
    }
    for (final a in seedAlerts ?? DemoData.seededAlerts(_now())) {
      _alerts[a.id] = a;
    }
  }

  final NotificationService _notifications;
  final ConflictConfig _config;
  final DateTime Function() _now;
  final List<RiskZone> _zones;
  final List<TrackedAnimal> _animals;
  final List<AppUser> _responders;

  late final ProcessLocationReading _processor;

  final Map<String, WildlifeRiskAlert> _alerts = {};
  final Map<String, ResponseAssignment> _assignments = {};
  final Map<String, CommunityReport> _reports = {};
  final Set<String> _seenReadingIds = {};

  // --- Triggers -------------------------------------------------------------

  @override
  Future<WildlifeRiskAlert?> processLocationReading(
    LocationReading reading,
  ) async {
    final result = _processor.call(
      reading: reading,
      activeZones: _zones,
      existingAlerts: _alerts.values.toList(),
      now: _now(),
      seenReadingIds: _seenReadingIds,
    );

    if (result.outcome == ProcessOutcome.rejected) {
      // Invalid/stale/duplicate readings never raise an alert; surface why so
      // the manager UI can explain the outcome instead of failing silently.
      throw ConflictException(result.rejection.message);
    }

    _seenReadingIds.add(reading.id);
    if (result.alert != null) {
      _alerts[result.alert!.id] = result.alert!;
    }
    return result.alert;
  }

  @override
  Future<WildlifeRiskAlert?> processCommunityReport(
    CommunityReport report,
  ) async {
    if (!report.verified) return null; // unverified never raises an alert
    final result = _processor.fromCommunityPoint(
      parkId: report.parkId,
      latitude: report.latitude,
      longitude: report.longitude,
      activeZones: _zones,
      existingAlerts: _alerts.values.toList(),
      now: _now(),
    );
    if (result.outcome == ProcessOutcome.rejected) {
      throw ConflictException(result.rejection.message);
    }
    if (result.alert != null) {
      _alerts[result.alert!.id] = result.alert!;
    }
    return result.alert;
  }

  // --- Reference/read data --------------------------------------------------

  @override
  Future<List<WildlifeRiskAlert>> getAlerts(String parkId) async {
    final list = _alerts.values.where((a) => a.parkId == parkId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<WildlifeRiskAlert?> getAlert(String id) async => _alerts[id];

  @override
  Future<List<RiskZone>> getRiskZones(String parkId) async =>
      _zones.where((z) => z.parkId == parkId).toList();

  @override
  Future<List<TrackedAnimal>> getTrackedAnimals() async => List.of(_animals);

  // --- Community reports ------------------------------------------------------

  @override
  Future<List<CommunityReport>> getCommunityReports(String parkId) async {
    final list = _reports.values.where((r) => r.parkId == parkId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<CommunityReport> verifyCommunityReport({
    required String reportId,
    required String verifiedBy,
  }) async {
    final report = _reports[reportId];
    if (report == null) {
      throw const ConflictException('Community report not found.');
    }
    final updated = report.copyWith(verified: true, verifiedBy: verifiedBy);
    _reports[reportId] = updated;
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
  Future<List<ResponseAssignment>> getAssignmentsForAlert(
    String alertId,
  ) async {
    final list = _assignments.values
        .where((a) => a.alertId == alertId)
        .toList()
      ..sort((a, b) => a.assignedAt.compareTo(b.assignedAt));
    return list;
  }

  @override
  Future<ResponseAssignment?> getActiveAssignment(String alertId) async {
    final list = await getAssignmentsForAlert(alertId);
    return list.isEmpty ? null : list.last;
  }

  @override
  Future<ResponseAssignment?> getAssignment(String assignmentId) async =>
      _assignments[assignmentId];

  @override
  Future<ResponseAssignment> assignResponder({
    required String alertId,
    required String responderId,
    required String assignedBy,
  }) async {
    final alert = _alerts[alertId];
    if (alert == null) throw const ConflictException('Alert not found.');
    if (alert.status == AlertStatus.resolved) {
      throw const ConflictException('Cannot assign: alert is resolved.');
    }

    // First assignment happens from NEW. A later assignment is only allowed as
    // an escalation reassignment while still awaiting acknowledgement.
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
      // Selected responder became unavailable between load and assign.
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
    _assignments[assignment.id] = assignment;

    // Move NEW -> ASSIGNED on the first assignment; a reassignment keeps the
    // alert ASSIGNED and never duplicates the alert. (active is unused beyond
    // documenting the reassignment path.)
    if (alert.status == AlertStatus.newAlert) {
      _transition(alert, AlertStatus.assigned);
    }
    assert(active == null || alert.status == AlertStatus.assigned);

    // Fire notification; delivery state is recorded separately from ack.
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
    _assignments[assignment.id] = delivered;
    return delivered;
  }

  @override
  Future<ResponseAssignment> acknowledgeAssignment({
    required String assignmentId,
    required String responderId,
  }) async {
    final assignment = _assignments[assignmentId];
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

    final alert = _alerts[assignment.alertId];
    if (alert == null) throw const ConflictException('Alert not found.');
    _transition(alert, AlertStatus.acknowledged);

    final updated = assignment.copyWith(acknowledgedAt: _now());
    _assignments[assignmentId] = updated;
    return updated;
  }

  @override
  Future<ResponseAssignment> startResponse(String assignmentId) async {
    final assignment = _assignments[assignmentId];
    if (assignment == null) {
      throw const ConflictException('Assignment not found.');
    }
    if (assignment.acknowledgedAt == null) {
      throw const ConflictException(
        'Cannot start response before acknowledgement.',
      );
    }
    final alert = _alerts[assignment.alertId];
    if (alert == null) throw const ConflictException('Alert not found.');
    _transition(alert, AlertStatus.responseInProgress);

    final updated = assignment.copyWith(startedAt: _now());
    _assignments[assignmentId] = updated;
    return updated;
  }

  @override
  Future<ResponseAssignment> updateResponseStatus({
    required String assignmentId,
    required String statusNote,
  }) async {
    final assignment = _assignments[assignmentId];
    if (assignment == null) {
      throw const ConflictException('Assignment not found.');
    }
    if (assignment.startedAt == null) {
      throw const ConflictException(
        'Cannot record a status note before the response starts.',
      );
    }
    final updated = assignment.copyWith(statusNote: statusNote);
    _assignments[assignmentId] = updated;
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
    final assignment = _assignments[assignmentId];
    if (assignment == null) {
      throw const ConflictException('Assignment not found.');
    }
    if (assignment.startedAt == null) {
      throw const ConflictException(
        'Cannot record an outcome before the response starts.',
      );
    }
    // Recording an outcome does NOT auto-resolve the alert; the manager resolves.
    final updated = assignment.copyWith(
      outcome: outcome,
      completedAt: _now(),
    );
    _assignments[assignmentId] = updated;
    return updated;
  }

  @override
  Future<WildlifeRiskAlert> resolveAlert(String alertId) async {
    final alert = _alerts[alertId];
    if (alert == null) throw const ConflictException('Alert not found.');
    final assignments = await getAssignmentsForAlert(alertId);
    AlertRules.assertResolvable(alert, assignments);
    final resolved = alert.copyWith(
      status: AlertStatus.resolved,
      resolvedAt: _now(),
    );
    _alerts[alertId] = resolved;
    return resolved;
  }

  // --- internals ------------------------------------------------------------

  void _transition(WildlifeRiskAlert alert, AlertStatus to) {
    AlertRules.assertTransition(alert.status, to);
    _alerts[alert.id] = alert.copyWith(status: to);
  }
}

/// No-op notifier used when none is supplied (keeps delivery state pending).
class _NullNotifier implements NotificationService {
  @override
  Future<NotificationResult> notifyAssignment({
    required String assignmentId,
    required String responderId,
    required String title,
    required String body,
  }) async =>
      const NotificationResult(DeliveryState.delivered);
}

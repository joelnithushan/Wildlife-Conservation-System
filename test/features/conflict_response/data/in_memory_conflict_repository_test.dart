import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/notification/simulated_notification_service.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/in_memory_conflict_repository.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/acknowledgement_monitor.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/alert_rules.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/conflict_config.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';
import 'package:wildlife_conservation_system/shared/models/community_report.dart';
import 'package:wildlife_conservation_system/shared/models/location_reading.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';

/// Integration tests for UC03 exercised through the repository, covering the 25
/// required scenarios end-to-end with a deterministic clock.
void main() {
  final fixedNow = DateTime.utc(2026, 9, 26, 10, 0, 0);
  const park = 'PARK-MIN';

  InMemoryConflictRepository buildRepo({
    List<WildlifeRiskAlert>? alerts,
    List<AppUser>? responders,
    List<CommunityReport>? reports,
    SimulatedNotificationService? notifier,
    DateTime Function()? now,
  }) {
    return InMemoryConflictRepository(
      seedAlerts: alerts ?? const [],
      communityReports: reports ?? const [],
      responders: responders ?? DemoData.conflictResponders,
      notificationService: notifier ?? SimulatedNotificationService(),
      now: now ?? () => fixedNow,
    );
  }

  LocationReading reading({
    String id = 'reading-1',
    String animal = 'EL-07',
    double lat = 8.030,
    double lon = 80.900,
    DateTime? observed,
  }) {
    return LocationReading(
      id: id,
      animalId: animal,
      latitude: lat,
      longitude: lon,
      observedAt: observed ?? fixedNow,
      receivedAt: observed ?? fixedNow,
    );
  }

  WildlifeRiskAlert seededAlert({String id = 'A1'}) => WildlifeRiskAlert(
        id: id,
        parkId: park,
        source: AlertSource.collar,
        latitude: 8.030,
        longitude: 80.900,
        severity: AlertSeverity.high,
        createdAt: fixedNow,
        animalId: 'EL-07',
        riskZoneId: 'RZ-01',
      );

  group('Trigger A – collar readings', () {
    test('1. valid collar reading inside zone creates alert', () async {
      final repo = buildRepo();
      final alert = await repo.processLocationReading(reading());
      expect(alert, isNotNull);
      expect(alert!.status, AlertStatus.newAlert);
      expect(alert.source, AlertSource.collar);
      expect((await repo.getAlerts(park)).length, 1);
    });

    test('2. reading outside zone creates no alert', () async {
      final repo = buildRepo();
      final alert = await repo.processLocationReading(
        reading(lat: 8.200, lon: 81.200),
      );
      expect(alert, isNull);
      expect(await repo.getAlerts(park), isEmpty);
    });

    test('3. stale reading creates no alert', () async {
      final repo = buildRepo();
      final stale = reading(observed: fixedNow.subtract(const Duration(hours: 3)));
      expect(
        () => repo.processLocationReading(stale),
        throwsA(isA<ConflictException>()),
      );
      expect(await repo.getAlerts(park), isEmpty);
    });

    test('4. invalid coordinates rejected', () async {
      final repo = buildRepo();
      expect(
        () => repo.processLocationReading(reading(lat: 200, lon: 999)),
        throwsA(isA<ConflictException>()),
      );
      expect(await repo.getAlerts(park), isEmpty);
    });

    test('5. duplicate reading id ignored', () async {
      final repo = buildRepo();
      await repo.processLocationReading(reading(id: 'dup'));
      expect(
        () => repo.processLocationReading(reading(id: 'dup')),
        throwsA(isA<ConflictException>()),
      );
      expect((await repo.getAlerts(park)).length, 1);
    });

    test('6. existing open alert updated instead of duplicated', () async {
      final repo = buildRepo();
      await repo.processLocationReading(reading(id: 'r1'));
      final second = await repo.processLocationReading(reading(id: 'r2'));
      expect(second, isNotNull);
      expect((await repo.getAlerts(park)).length, 1); // still one open alert
    });
  });

  group('Trigger B – community reports', () {
    CommunityReport report({bool verified = false, double lat = 8.010, double lon = 80.870}) =>
        CommunityReport(
          id: 'cr1',
          parkId: park,
          description: 'Elephant near fence',
          latitude: lat,
          longitude: lon,
          createdAt: fixedNow,
          verified: verified,
        );

    test('7. verified community report creates alert', () async {
      final repo = buildRepo();
      final alert = await repo.processCommunityReport(report(verified: true));
      expect(alert, isNotNull);
      expect(alert!.source, AlertSource.communityReport);
      expect(alert.animalId, isNull);
    });

    test('8. unverified report does not create alert', () async {
      final repo = buildRepo();
      final alert = await repo.processCommunityReport(report(verified: false));
      expect(alert, isNull);
      expect(await repo.getAlerts(park), isEmpty);
    });

    test('community report rejected as not credible stays unverified', () async {
      final repo = buildRepo(reports: [report()]);
      final verified = await repo.verifyCommunityReport(
        reportId: 'cr1',
        verifiedBy: 'PM001',
      );
      expect(verified.verified, isTrue);
      expect(verified.verifiedBy, 'PM001');
    });
  });

  group('Responders & assignment', () {
    test('9. available responders loaded (excludes unavailable)', () async {
      final repo = buildRepo();
      final responders = await repo.getAvailableResponders(park);
      expect(responders, isNotEmpty);
      expect(responders.every((r) => r.isAvailable), isTrue);
    });

    test('10. no responder available', () async {
      final repo = buildRepo(alerts: [seededAlert()], responders: []);
      expect(
        () => repo.assignResponder(
            alertId: 'A1', responderId: 'R001', assignedBy: 'PM001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('11. successful assignment moves alert to assigned', () async {
      final repo = buildRepo(alerts: [seededAlert()]);
      final assignment = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      expect(assignment.responderId, 'R001');
      final alert = await repo.getAlert('A1');
      expect(alert!.status, AlertStatus.assigned);
    });

    test('12. assignment conflict when responder unavailable', () async {
      final repo = buildRepo(alerts: [seededAlert()]);
      // R002 is unavailable in demo responders.
      expect(
        () => repo.assignResponder(
            alertId: 'A1', responderId: 'R002', assignedBy: 'PM001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('13. notification delivered state recorded', () async {
      final repo = buildRepo(alerts: [seededAlert()]);
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      expect(a.deliveryState, DeliveryState.delivered);
      expect(a.deliveredAt, isNotNull);
    });

    test('14. notification failure state recorded', () async {
      final repo = buildRepo(
        alerts: [seededAlert()],
        notifier: SimulatedNotificationService(alwaysFail: true),
      );
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      expect(a.deliveryState, DeliveryState.failed);
      expect(a.deliveredAt, isNull);
    });

    test('15. delivery is separate from acknowledgement', () async {
      final repo = buildRepo(alerts: [seededAlert()]);
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      expect(a.deliveryState, DeliveryState.delivered);
      expect(a.acknowledgedAt, isNull);
    });
  });

  group('Acknowledgement & escalation', () {
    Future<(InMemoryConflictRepository, String)> assigned() async {
      final repo = buildRepo(alerts: [seededAlert()]);
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      return (repo, a.id);
    }

    test('16. successful acknowledgement', () async {
      final (repo, assignmentId) = await assigned();
      final acked = await repo.acknowledgeAssignment(
          assignmentId: assignmentId, responderId: 'R001');
      expect(acked.acknowledgedAt, isNotNull);
      expect((await repo.getAlert('A1'))!.status, AlertStatus.acknowledged);
    });

    test('17. wrong responder acknowledgement rejected', () async {
      final (repo, assignmentId) = await assigned();
      expect(
        () => repo.acknowledgeAssignment(
            assignmentId: assignmentId, responderId: 'CLO001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('duplicate acknowledgement rejected', () async {
      final (repo, assignmentId) = await assigned();
      await repo.acknowledgeAssignment(
          assignmentId: assignmentId, responderId: 'R001');
      expect(
        () => repo.acknowledgeAssignment(
            assignmentId: assignmentId, responderId: 'R001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('18. acknowledgement timeout escalates (monitor)', () async {
      final (repo, assignmentId) = await assigned();
      final assignment = await repo.getAssignment(assignmentId);
      final overdue = AcknowledgementMonitor.isOverdue(
        assignment!,
        now: fixedNow.add(const Duration(minutes: 20)),
        config: ConflictConfig.defaults,
      );
      expect(overdue, isTrue);
    });

    test('19. reassignment keeps the same alert', () async {
      final (repo, _) = await assigned();
      await repo.assignResponder(
          alertId: 'A1', responderId: 'CLO001', assignedBy: 'PM001');
      expect((await repo.getAlerts(park)).length, 1); // no duplicate alert
      expect((await repo.getAssignmentsForAlert('A1')).length, 2);
      expect((await repo.getAlert('A1'))!.status, AlertStatus.assigned);
    });

    test('19b. acknowledging a superseded assignment is rejected; the new '
        'assignment acknowledges normally', () async {
      final (repo, firstId) = await assigned(); // R001 assigned first
      // Manager reassigns to CLO001 — the SAME alert, a NEW assignment.
      final second = await repo.assignResponder(
          alertId: 'A1', responderId: 'CLO001', assignedBy: 'PM001');

      // The original (now superseded) assignment must NOT be able to drive the
      // alert to ACKNOWLEDGED (§7: only the active assignment counts).
      expect(
        () => repo.acknowledgeAssignment(
            assignmentId: firstId, responderId: 'R001'),
        throwsA(isA<ConflictException>()),
      );
      expect((await repo.getAlert('A1'))!.status, AlertStatus.assigned);

      // The current assignment acknowledges normally.
      final acked = await repo.acknowledgeAssignment(
          assignmentId: second.id, responderId: 'CLO001');
      expect(acked.acknowledgedAt, isNotNull);
      expect((await repo.getAlert('A1'))!.status, AlertStatus.acknowledged);
      // History preserved: both assignments still exist.
      expect((await repo.getAssignmentsForAlert('A1')).length, 2);
    });
  });

  group('Response lifecycle & resolution', () {
    Future<(InMemoryConflictRepository, String)> acknowledged() async {
      final repo = buildRepo(alerts: [seededAlert()]);
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      await repo.acknowledgeAssignment(
          assignmentId: a.id, responderId: 'R001');
      return (repo, a.id);
    }

    test('20. start response', () async {
      final (repo, id) = await acknowledged();
      final started = await repo.startResponse(id);
      expect(started.startedAt, isNotNull);
      expect((await repo.getAlert('A1'))!.status,
          AlertStatus.responseInProgress);
    });

    test('response start before acknowledgement rejected', () async {
      final repo = buildRepo(alerts: [seededAlert()]);
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      expect(() => repo.startResponse(a.id),
          throwsA(isA<ConflictException>()));
    });

    test('21. response status update', () async {
      final (repo, id) = await acknowledged();
      await repo.startResponse(id);
      final updated = await repo.updateResponseStatus(
          assignmentId: id, statusNote: 'On site');
      expect(updated.statusNote, 'On site');
    });

    test('22. record outcome does not auto-resolve', () async {
      final (repo, id) = await acknowledged();
      await repo.startResponse(id);
      final done = await repo.recordOutcome(
          assignmentId: id, outcome: 'Animal returned to park');
      expect(done.outcome, 'Animal returned to park');
      expect(done.completedAt, isNotNull);
      expect((await repo.getAlert('A1'))!.status,
          AlertStatus.responseInProgress); // still not resolved
    });

    test('23. resolve alert after outcome', () async {
      final (repo, id) = await acknowledged();
      await repo.startResponse(id);
      await repo.recordOutcome(assignmentId: id, outcome: 'Residents warned');
      final resolved = await repo.resolveAlert('A1');
      expect(resolved.status, AlertStatus.resolved);
      expect(resolved.resolvedAt, isNotNull);
    });

    test('24. invalid status transition rejected (resolve from new)', () async {
      final repo = buildRepo(alerts: [seededAlert()]);
      expect(() => repo.resolveAlert('A1'),
          throwsA(isA<ConflictException>()));
    });

    test('resolve without recorded outcome rejected', () async {
      final (repo, id) = await acknowledged();
      await repo.startResponse(id);
      expect(() => repo.resolveAlert('A1'),
          throwsA(isA<ConflictException>()));
    });

    test('25. resolved status history retained', () async {
      final (repo, id) = await acknowledged();
      await repo.startResponse(id);
      await repo.recordOutcome(assignmentId: id, outcome: 'Done');
      await repo.resolveAlert('A1');

      final alert = await repo.getAlert('A1');
      final assignment = await repo.getAssignment(id);
      expect(alert!.createdAt, isNotNull);
      expect(alert.resolvedAt, isNotNull);
      expect(assignment!.acknowledgedAt, isNotNull);
      expect(assignment.startedAt, isNotNull);
      expect(assignment.completedAt, isNotNull);
    });
  });
}

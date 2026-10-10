import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/datasources/conflict_local_data_source.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/notification/simulated_notification_service.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/drift_conflict_repository.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/alert_rules.dart';
import 'package:wildlife_conservation_system/shared/models/community_report.dart';
import 'package:wildlife_conservation_system/shared/models/location_reading.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';

import '../../../patrol/helpers.dart';

/// Behavioural coverage for [DriftConflictRepository] over the full UC03
/// lifecycle, mirroring the Firestore repository tests but against in-memory
/// Drift. A sentinel alert in a throwaway park keeps the alerts table non-empty
/// so the repository's one-time demo seeding is suppressed and PARK-MIN starts
/// clean and deterministic.
void main() {
  final fixedNow = DateTime.utc(2026, 9, 26, 10, 0, 0);
  const park = 'PARK-MIN';

  late AppDatabase db;
  late ConflictLocalDataSource local;

  DriftConflictRepository buildRepo({
    SimulatedNotificationService? notifier,
    DateTime Function()? now,
  }) =>
      DriftConflictRepository(
        localDataSource: local,
        notificationService: notifier ?? SimulatedNotificationService(),
        now: now ?? () => fixedNow,
      );

  WildlifeRiskAlert seededAlert({
    String id = 'A1',
    String parkId = park,
    AlertStatus status = AlertStatus.newAlert,
    DateTime? createdAt,
  }) =>
      WildlifeRiskAlert(
        id: id,
        parkId: parkId,
        source: AlertSource.collar,
        latitude: 8.030,
        longitude: 80.900,
        severity: AlertSeverity.high,
        createdAt: createdAt ?? fixedNow,
        animalId: 'EL-07',
        riskZoneId: 'RZ-01',
        status: status,
      );

  LocationReading reading({
    String id = 'reading-1',
    double lat = 8.030,
    double lon = 80.900,
    DateTime? observed,
  }) =>
      LocationReading(
        id: id,
        animalId: 'EL-07',
        latitude: lat,
        longitude: lon,
        observedAt: observed ?? fixedNow,
        receivedAt: observed ?? fixedNow,
      );

  // Suppress the repository's demo auto-seed by making the alerts table
  // non-empty. The sentinel is resolved and far from any zone so the
  // deduplicating processor never treats it as an open alert to update.
  Future<void> suppressDemoSeed() => local.upsertAlert(WildlifeRiskAlert(
        id: 'SENTINEL',
        parkId: 'ZZZ-PARK',
        source: AlertSource.collar,
        latitude: 1.0,
        longitude: 1.0,
        severity: AlertSeverity.low,
        createdAt: fixedNow,
        animalId: 'ZZZ',
        riskZoneId: 'ZZZ',
        status: AlertStatus.resolved,
      ));

  setUp(() {
    db = createTestDatabase();
    local = ConflictLocalDataSource(db);
  });
  tearDown(() => db.close());

  group('Triggers', () {
    test('valid collar reading inside a zone creates a new alert', () async {
      await suppressDemoSeed();
      final repo = buildRepo();
      final alert = await repo.processLocationReading(reading());
      expect(alert, isNotNull);
      expect(alert!.source, AlertSource.collar);
      expect((await repo.getAlerts(park)), hasLength(1));
      // A creation status-change was recorded.
      expect(await repo.getStatusHistory(alert.id), isNotEmpty);
    });

    test('reading outside every zone creates no alert', () async {
      await suppressDemoSeed();
      final repo = buildRepo();
      final alert =
          await repo.processLocationReading(reading(lat: 8.3, lon: 81.3));
      expect(alert, isNull);
      expect(await repo.getAlerts(park), isEmpty);
    });

    test('duplicate reading id is rejected', () async {
      await suppressDemoSeed();
      final repo = buildRepo();
      await repo.processLocationReading(reading(id: 'dup'));
      expect(() => repo.processLocationReading(reading(id: 'dup')),
          throwsA(isA<ConflictException>()));
    });

    test('verified community report creates a community alert', () async {
      await suppressDemoSeed();
      final repo = buildRepo();
      final alert = await repo.processCommunityReport(CommunityReport(
        id: 'cr1',
        parkId: park,
        description: 'near fence',
        latitude: 8.030,
        longitude: 80.900,
        createdAt: fixedNow,
        verified: true,
        verifiedBy: 'CLO001',
      ));
      expect(alert, isNotNull);
      expect(alert!.source, AlertSource.communityReport);
    });

    test('unverified community report creates no alert', () async {
      await suppressDemoSeed();
      final repo = buildRepo();
      final alert = await repo.processCommunityReport(CommunityReport(
        id: 'cr2',
        parkId: park,
        description: 'x',
        latitude: 8.030,
        longitude: 80.900,
        createdAt: fixedNow,
      ));
      expect(alert, isNull);
    });
  });

  group('Reads & community reports', () {
    test('getAlert returns null for an unknown id', () async {
      await suppressDemoSeed();
      expect(await buildRepo().getAlert('nope'), isNull);
    });

    test('getRiskZones filters by park and getTrackedAnimals returns demo set',
        () async {
      final repo = buildRepo();
      expect((await repo.getRiskZones(park)).every((z) => z.parkId == park),
          isTrue);
      expect(await repo.getTrackedAnimals(), isNotEmpty);
    });

    test('getAvailableResponders excludes unavailable responders', () async {
      final repo = buildRepo();
      final responders = await repo.getAvailableResponders(park);
      expect(responders, isNotEmpty);
      expect(responders.every((r) => r.isAvailable && r.isResponder), isTrue);
      expect(responders.any((r) => r.id == 'R002'), isFalse);
    });

    test('submit then verify a community report', () async {
      await suppressDemoSeed();
      final repo = buildRepo();
      final report = CommunityReport.create(
        parkId: park,
        description: 'sighting',
        latitude: 8.0,
        longitude: 80.0,
        createdAt: fixedNow,
      );
      await repo.submitCommunityReport(report);
      expect(await repo.getCommunityReports(park), hasLength(1));

      final verified = await repo.verifyCommunityReport(
          reportId: report.id, verifiedBy: 'PM001');
      expect(verified.verified, isTrue);
      expect(verified.verifiedBy, 'PM001');
    });

    test('verifyCommunityReport throws when the report is missing', () async {
      await suppressDemoSeed();
      expect(
        () => buildRepo()
            .verifyCommunityReport(reportId: 'ghost', verifiedBy: 'PM001'),
        throwsA(isA<ConflictException>()),
      );
    });
  });

  group('Assignment', () {
    test('assignResponder moves the alert to assigned and delivers', () async {
      await suppressDemoSeed();
      await local.upsertAlert(seededAlert());
      final repo = buildRepo();
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      expect(a.deliveryState, DeliveryState.delivered);
      expect((await repo.getAlert('A1'))!.status, AlertStatus.assigned);
    });

    test('assignResponder rejects a missing alert', () async {
      await suppressDemoSeed();
      expect(
        () => buildRepo().assignResponder(
            alertId: 'ghost', responderId: 'R001', assignedBy: 'PM001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('assignResponder rejects a resolved alert', () async {
      await suppressDemoSeed();
      await local.upsertAlert(seededAlert(status: AlertStatus.resolved));
      expect(
        () => buildRepo().assignResponder(
            alertId: 'A1', responderId: 'R001', assignedBy: 'PM001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('assignResponder rejects an unavailable/unknown responder', () async {
      await suppressDemoSeed();
      await local.upsertAlert(seededAlert());
      expect(
        () => buildRepo().assignResponder(
            alertId: 'A1', responderId: 'R002', assignedBy: 'PM001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('failed delivery is recorded and retry re-sends', () async {
      await suppressDemoSeed();
      await local.upsertAlert(seededAlert());
      final repo =
          buildRepo(notifier: SimulatedNotificationService(alwaysFail: true));
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      expect(a.deliveryState, DeliveryState.failed);

      final repo2 = buildRepo(); // delivering notifier
      final retried = await repo2.retryNotificationDelivery(a.id);
      expect(retried.deliveryState, DeliveryState.delivered);
    });

    test('retryNotificationDelivery rejects an unknown assignment', () async {
      await suppressDemoSeed();
      expect(() => buildRepo().retryNotificationDelivery('ghost'),
          throwsA(isA<ConflictException>()));
    });

    test('reassignment keeps one alert and preserves assignment history',
        () async {
      await suppressDemoSeed();
      await local.upsertAlert(seededAlert());
      final repo = buildRepo();
      await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      final second = await repo.assignResponder(
          alertId: 'A1', responderId: 'CLO001', assignedBy: 'PM001');
      expect(await repo.getAlerts(park), hasLength(1));
      expect(await repo.getAssignmentsForAlert('A1'), hasLength(2));
      expect((await repo.getActiveAssignment('A1'))!.id, second.id);
    });
  });

  group('Lifecycle & resolution', () {
    Future<(DriftConflictRepository, String)> assigned() async {
      await suppressDemoSeed();
      await local.upsertAlert(seededAlert());
      final repo = buildRepo();
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      return (repo, a.id);
    }

    test('acknowledge → start → status → outcome → resolve', () async {
      final (repo, id) = await assigned();
      await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      expect((await repo.getAlert('A1'))!.status, AlertStatus.acknowledged);
      await repo.startResponse(id);
      expect((await repo.getAlert('A1'))!.status,
          AlertStatus.responseInProgress);
      final noted = await repo.updateResponseStatus(
          assignmentId: id, statusNote: 'On site');
      expect(noted.statusNote, 'On site');
      await repo.recordOutcome(assignmentId: id, outcome: 'Herded away');
      final resolved = await repo.resolveAlert('A1');
      expect(resolved.status, AlertStatus.resolved);
      // Full status history retained across the lifecycle.
      expect((await repo.getStatusHistory('A1')).length, greaterThanOrEqualTo(4));
    });

    test('wrong responder acknowledgement rejected', () async {
      final (repo, id) = await assigned();
      expect(
        () =>
            repo.acknowledgeAssignment(assignmentId: id, responderId: 'CLO001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('double acknowledgement rejected', () async {
      final (repo, id) = await assigned();
      await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      expect(
        () => repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('acknowledging a superseded assignment is rejected', () async {
      await suppressDemoSeed();
      await local.upsertAlert(seededAlert());
      final repo = buildRepo();
      final first = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      await repo.assignResponder(
          alertId: 'A1', responderId: 'CLO001', assignedBy: 'PM001');
      expect(
        () => repo.acknowledgeAssignment(
            assignmentId: first.id, responderId: 'R001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('start before acknowledgement rejected', () async {
      final (repo, id) = await assigned();
      expect(() => repo.startResponse(id), throwsA(isA<ConflictException>()));
    });

    test('status note before start rejected', () async {
      final (repo, id) = await assigned();
      await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      expect(
        () => repo.updateResponseStatus(assignmentId: id, statusNote: 'x'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('empty outcome rejected', () async {
      final (repo, id) = await assigned();
      await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      await repo.startResponse(id);
      expect(() => repo.recordOutcome(assignmentId: id, outcome: '  '),
          throwsA(isA<ConflictException>()));
    });

    test('resolve before outcome rejected', () async {
      final (repo, id) = await assigned();
      await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      await repo.startResponse(id);
      expect(() => repo.resolveAlert('A1'), throwsA(isA<ConflictException>()));
    });

    test('resolving a brand-new alert rejected', () async {
      await suppressDemoSeed();
      await local.upsertAlert(seededAlert());
      expect(() => buildRepo().resolveAlert('A1'),
          throwsA(isA<ConflictException>()));
    });

    test('overdue assigned alert is escalated and logs a status change',
        () async {
      await assigned();
      final later =
          buildRepo(now: () => fixedNow.add(const Duration(minutes: 30)));
      final overdue = await later.checkAndEscalateOverdueAlerts(parkId: park);
      expect(overdue.map((a) => a.id), contains('A1'));
      // Escalation appends a status-change entry.
      expect(
        (await later.getStatusHistory('A1'))
            .any((c) => (c.reason ?? '').contains('escalation')),
        isTrue,
      );
    });

    test('acknowledged alert is not escalated', () async {
      final (repo, id) = await assigned();
      await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      final later =
          buildRepo(now: () => fixedNow.add(const Duration(minutes: 30)));
      expect(await later.checkAndEscalateOverdueAlerts(parkId: park), isEmpty);
    });
  });
}

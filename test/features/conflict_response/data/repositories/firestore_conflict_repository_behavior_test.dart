import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/constants/firestore_collections.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/notification/simulated_notification_service.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/firestore_conflict_repository.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/acknowledgement_monitor.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/alert_rules.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/conflict_config.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';
import 'package:wildlife_conservation_system/shared/models/community_report.dart';
import 'package:wildlife_conservation_system/shared/models/location_reading.dart';
import 'package:wildlife_conservation_system/shared/models/tracked_animal.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';

/// Behavioural tests for [FirestoreConflictRepository] running against an
/// in-memory [FakeFirebaseFirestore]. These exercise the real Firestore code
/// paths (transactions, queries, set/merge) without touching the network, which
/// the sibling serialization test cannot do.
void main() {
  final fixedNow = DateTime.utc(2026, 9, 26, 10, 0, 0);
  const park = 'PARK-MIN';

  late FakeFirebaseFirestore fs;

  FirestoreConflictRepository buildRepo({
    SimulatedNotificationService? notifier,
    DateTime Function()? now,
  }) {
    return FirestoreConflictRepository(
      firestore: fs,
      notificationService: notifier ?? SimulatedNotificationService(),
      now: now ?? () => fixedNow,
    );
  }

  Future<void> seedRiskZones() async {
    for (final z in DemoData.riskZones) {
      await fs.collection(FirestoreCollections.riskZones).doc(z.id).set(z.toMap());
    }
  }

  Future<void> seedResponders() async {
    for (final u in DemoData.conflictResponders) {
      await fs.collection(FirestoreCollections.users).doc(u.id).set(u.toMap());
    }
  }

  Future<void> seedAlert(WildlifeRiskAlert alert) async {
    await fs
        .collection(FirestoreCollections.wildlifeRiskAlerts)
        .doc(alert.id)
        .set(alert.toMap());
  }

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

  WildlifeRiskAlert seededAlert({
    String id = 'A1',
    AlertStatus status = AlertStatus.newAlert,
    DateTime? createdAt,
  }) =>
      WildlifeRiskAlert(
        id: id,
        parkId: park,
        source: AlertSource.collar,
        latitude: 8.030,
        longitude: 80.900,
        severity: AlertSeverity.high,
        createdAt: createdAt ?? fixedNow,
        animalId: 'EL-07',
        riskZoneId: 'RZ-01',
        status: status,
      );

  setUp(() => fs = FakeFirebaseFirestore());

  group('Triggers', () {
    test('valid collar reading inside a zone persists reading + alert', () async {
      await seedRiskZones();
      final repo = buildRepo();

      final alert = await repo.processLocationReading(reading());

      expect(alert, isNotNull);
      expect(alert!.source, AlertSource.collar);
      // Reading was persisted under its stable id.
      final readingDoc = await fs
          .collection(FirestoreCollections.locationReadings)
          .doc('reading-1')
          .get();
      expect(readingDoc.exists, isTrue);
      expect((await repo.getAlerts(park)).length, 1);
    });

    test('reading outside every zone creates no alert', () async {
      await seedRiskZones();
      final repo = buildRepo();
      final alert =
          await repo.processLocationReading(reading(lat: 8.200, lon: 81.200));
      expect(alert, isNull);
      expect(await repo.getAlerts(park), isEmpty);
    });

    test('stale reading is rejected', () async {
      await seedRiskZones();
      final repo = buildRepo();
      expect(
        () => repo.processLocationReading(
            reading(observed: fixedNow.subtract(const Duration(hours: 3)))),
        throwsA(isA<ConflictException>()),
      );
    });

    test('duplicate reading id is rejected', () async {
      await seedRiskZones();
      final repo = buildRepo();
      await repo.processLocationReading(reading(id: 'dup'));
      expect(
        () => repo.processLocationReading(reading(id: 'dup')),
        throwsA(isA<ConflictException>()),
      );
    });

    test('verified community report creates a community-sourced alert',
        () async {
      await seedRiskZones();
      final repo = buildRepo();
      final report = CommunityReport(
        id: 'cr1',
        parkId: park,
        description: 'Elephant near fence',
        latitude: 8.030,
        longitude: 80.900,
        createdAt: fixedNow,
        verified: true,
      );
      final alert = await repo.processCommunityReport(report);
      expect(alert, isNotNull);
      expect(alert!.source, AlertSource.communityReport);
    });

    test('unverified community report creates no alert', () async {
      await seedRiskZones();
      final repo = buildRepo();
      final report = CommunityReport(
        id: 'cr2',
        parkId: park,
        description: 'x',
        latitude: 8.030,
        longitude: 80.900,
        createdAt: fixedNow,
      );
      expect(await repo.processCommunityReport(report), isNull);
    });
  });

  group('Reads', () {
    test('getAlerts returns park alerts newest-first', () async {
      await seedAlert(seededAlert(
          id: 'old', createdAt: fixedNow.subtract(const Duration(hours: 2))));
      await seedAlert(seededAlert(id: 'new'));
      final repo = buildRepo();
      final alerts = await repo.getAlerts(park);
      expect(alerts.map((a) => a.id).toList(), ['new', 'old']);
    });

    test('getAlert returns null for an unknown id', () async {
      final repo = buildRepo();
      expect(await repo.getAlert('missing'), isNull);
    });

    test('getAssignment returns null for an unknown id', () async {
      final repo = buildRepo();
      expect(await repo.getAssignment('missing'), isNull);
    });

    test('getTrackedAnimals maps stored docs', () async {
      final animal = TrackedAnimal(
        id: 'EL-07',
        code: 'Tusker',
        species: 'Elephant',
        collarId: 'C-1',
      );
      await fs
          .collection(FirestoreCollections.trackedAnimals)
          .doc(animal.id)
          .set(animal.toMap());
      final repo = buildRepo();
      final animals = await repo.getTrackedAnimals();
      expect(animals.single.id, 'EL-07');
    });

    test('getRiskZones filters by park', () async {
      await seedRiskZones();
      final repo = buildRepo();
      final zones = await repo.getRiskZones(park);
      expect(zones, isNotEmpty);
      expect(zones.every((z) => z.parkId == park), isTrue);
    });

    test('getStatusHistory returns an empty list (placeholder)', () async {
      final repo = buildRepo();
      expect(await repo.getStatusHistory('A1'), isEmpty);
    });
  });

  group('Community reports', () {
    test('getCommunityReports returns park reports newest-first', () async {
      await fs.collection(FirestoreCollections.communityReports).doc('r1').set(
          CommunityReport(
                  id: 'r1',
                  parkId: park,
                  description: 'a',
                  latitude: 8.0,
                  longitude: 80.0,
                  createdAt: fixedNow.subtract(const Duration(hours: 1)))
              .toMap());
      await fs.collection(FirestoreCollections.communityReports).doc('r2').set(
          CommunityReport(
                  id: 'r2',
                  parkId: park,
                  description: 'b',
                  latitude: 8.0,
                  longitude: 80.0,
                  createdAt: fixedNow)
              .toMap());
      final repo = buildRepo();
      final reports = await repo.getCommunityReports(park);
      expect(reports.map((r) => r.id).toList(), ['r2', 'r1']);
    });

    test('verifyCommunityReport marks a stored report verified', () async {
      await fs.collection(FirestoreCollections.communityReports).doc('cr1').set(
          CommunityReport(
                  id: 'cr1',
                  parkId: park,
                  description: 'a',
                  latitude: 8.0,
                  longitude: 80.0,
                  createdAt: fixedNow)
              .toMap());
      final repo = buildRepo();
      final verified =
          await repo.verifyCommunityReport(reportId: 'cr1', verifiedBy: 'PM001');
      expect(verified.verified, isTrue);
      expect(verified.verifiedBy, 'PM001');
    });

    test('verifyCommunityReport throws when the report is missing', () async {
      final repo = buildRepo();
      expect(
        () => repo.verifyCommunityReport(reportId: 'nope', verifiedBy: 'PM001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('submitCommunityReport persists the report', () async {
      final repo = buildRepo();
      final report = CommunityReport.create(
        parkId: park,
        description: 'New sighting',
        latitude: 8.0,
        longitude: 80.0,
        createdAt: fixedNow,
      );
      final saved = await repo.submitCommunityReport(report);
      final doc = await fs
          .collection(FirestoreCollections.communityReports)
          .doc(saved.id)
          .get();
      expect(doc.exists, isTrue);
    });
  });

  group('Responders & assignment', () {
    test('getAvailableResponders returns only available responders', () async {
      await seedResponders();
      final repo = buildRepo();
      final responders = await repo.getAvailableResponders(park);
      expect(responders, isNotEmpty);
      expect(responders.every((r) => r.isAvailable && r.isResponder), isTrue);
      expect(responders.any((r) => r.id == 'R002'), isFalse); // unavailable
    });

    test('assignResponder moves the alert to assigned and delivers a notice',
        () async {
      await seedResponders();
      await seedAlert(seededAlert());
      final repo = buildRepo();

      final assignment = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');

      expect(assignment.responderId, 'R001');
      expect(assignment.deliveryState, DeliveryState.delivered);
      expect((await repo.getAlert('A1'))!.status, AlertStatus.assigned);
    });

    test('assignResponder records a failed delivery state', () async {
      await seedResponders();
      await seedAlert(seededAlert());
      final repo =
          buildRepo(notifier: SimulatedNotificationService(alwaysFail: true));
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      expect(a.deliveryState, DeliveryState.failed);
      expect(a.deliveredAt, isNull);
    });

    test('assignResponder rejects a missing alert', () async {
      await seedResponders();
      final repo = buildRepo();
      expect(
        () => repo.assignResponder(
            alertId: 'ghost', responderId: 'R001', assignedBy: 'PM001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('assignResponder rejects an unavailable responder', () async {
      await seedResponders();
      await seedAlert(seededAlert());
      final repo = buildRepo();
      expect(
        () => repo.assignResponder(
            alertId: 'A1', responderId: 'R002', assignedBy: 'PM001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('assignResponder rejects assigning onto a resolved alert', () async {
      await seedResponders();
      await seedAlert(seededAlert(status: AlertStatus.resolved));
      final repo = buildRepo();
      expect(
        () => repo.assignResponder(
            alertId: 'A1', responderId: 'R001', assignedBy: 'PM001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('getAssignmentsForAlert and getActiveAssignment track history',
        () async {
      await seedResponders();
      await seedAlert(seededAlert());
      final repo = buildRepo();
      await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      final second = await repo.assignResponder(
          alertId: 'A1', responderId: 'CLO001', assignedBy: 'PM001');

      expect((await repo.getAssignmentsForAlert('A1')).length, 2);
      expect((await repo.getActiveAssignment('A1'))!.id, second.id);
    });

    test('retryNotificationDelivery re-sends and updates delivery state',
        () async {
      await seedResponders();
      await seedAlert(seededAlert());
      final repo =
          buildRepo(notifier: SimulatedNotificationService(alwaysFail: true));
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      expect(a.deliveryState, DeliveryState.failed);

      // Swap to a delivering notifier and retry.
      final repo2 = buildRepo();
      final retried = await repo2.retryNotificationDelivery(a.id);
      expect(retried.deliveryState, DeliveryState.delivered);
    });
  });

  group('Lifecycle, escalation & resolution', () {
    Future<(FirestoreConflictRepository, String)> assigned(
        {DateTime Function()? now}) async {
      await seedResponders();
      await seedAlert(seededAlert());
      final repo = buildRepo(now: now);
      final a = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      return (repo, a.id);
    }

    test('acknowledge → start → status → outcome → resolve', () async {
      final (repo, id) = await assigned();

      final acked =
          await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      expect(acked.acknowledgedAt, isNotNull);
      expect((await repo.getAlert('A1'))!.status, AlertStatus.acknowledged);

      final started = await repo.startResponse(id);
      expect(started.startedAt, isNotNull);
      expect((await repo.getAlert('A1'))!.status,
          AlertStatus.responseInProgress);

      final noted = await repo.updateResponseStatus(
          assignmentId: id, statusNote: 'On site');
      expect(noted.statusNote, 'On site');

      final done =
          await repo.recordOutcome(assignmentId: id, outcome: 'Animal herded');
      expect(done.completedAt, isNotNull);

      final resolved = await repo.resolveAlert('A1');
      expect(resolved.status, AlertStatus.resolved);
      expect(resolved.resolvedAt, isNotNull);
    });

    test('acknowledge by the wrong responder is rejected', () async {
      final (repo, id) = await assigned();
      expect(
        () => repo.acknowledgeAssignment(assignmentId: id, responderId: 'CLO001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('double acknowledge is rejected', () async {
      final (repo, id) = await assigned();
      await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      expect(
        () => repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('acknowledging a superseded assignment is rejected', () async {
      await seedResponders();
      await seedAlert(seededAlert());
      final repo = buildRepo();
      final first = await repo.assignResponder(
          alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
      await repo.assignResponder(
          alertId: 'A1', responderId: 'CLO001', assignedBy: 'PM001');
      expect(
        () =>
            repo.acknowledgeAssignment(assignmentId: first.id, responderId: 'R001'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('starting before acknowledgement is rejected', () async {
      final (repo, id) = await assigned();
      expect(() => repo.startResponse(id), throwsA(isA<ConflictException>()));
    });

    test('status note before start is rejected', () async {
      final (repo, id) = await assigned();
      await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      expect(
        () => repo.updateResponseStatus(assignmentId: id, statusNote: 'x'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('empty outcome is rejected', () async {
      final (repo, id) = await assigned();
      await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      await repo.startResponse(id);
      expect(
        () => repo.recordOutcome(assignmentId: id, outcome: '   '),
        throwsA(isA<ConflictException>()),
      );
    });

    test('resolve before an outcome is rejected', () async {
      final (repo, id) = await assigned();
      await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      await repo.startResponse(id);
      expect(() => repo.resolveAlert('A1'), throwsA(isA<ConflictException>()));
    });

    test('resolving a brand-new alert is rejected', () async {
      await seedAlert(seededAlert());
      final repo = buildRepo();
      expect(() => repo.resolveAlert('A1'), throwsA(isA<ConflictException>()));
    });

    test('checkAndEscalateOverdueAlerts flags an unacknowledged assignment',
        () async {
      // Assign at fixedNow, then evaluate well past the ack deadline.
      await assigned();
      final later = buildRepo(
          now: () => fixedNow.add(const Duration(minutes: 30)));
      final overdue =
          await later.checkAndEscalateOverdueAlerts(parkId: park);
      expect(overdue.map((a) => a.id), contains('A1'));
    });

    test('checkAndEscalateOverdueAlerts ignores acknowledged assignments',
        () async {
      final (repo, id) = await assigned();
      await repo.acknowledgeAssignment(assignmentId: id, responderId: 'R001');
      final later = buildRepo(
          now: () => fixedNow.add(const Duration(minutes: 30)));
      final overdue = await later.checkAndEscalateOverdueAlerts(parkId: park);
      expect(overdue, isEmpty);
    });

    test('isOverdue monitor agrees with the escalation window', () async {
      final (repo, id) = await assigned();
      final assignment = await repo.getAssignment(id);
      expect(
        AcknowledgementMonitor.isOverdue(assignment!,
            now: fixedNow.add(const Duration(minutes: 30)),
            config: ConflictConfig.defaults),
        isTrue,
      );
    });
  });

  group('friendlyFirestoreMessage', () {
    test('maps known codes and falls back for unknown', () {
      expect(friendlyFirestoreMessage('permission-denied'),
          contains('permission'));
      expect(friendlyFirestoreMessage('not-found'), contains('could not'));
      expect(friendlyFirestoreMessage('unavailable'), contains('temporarily'));
      expect(friendlyFirestoreMessage('unauthenticated'), contains('session'));
      expect(friendlyFirestoreMessage('aborted'), contains('conflicted'));
      expect(friendlyFirestoreMessage('weird'), contains('Something went wrong'));
    });
  });
}

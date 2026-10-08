import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/sync/sync_service.dart';
import 'package:wildlife_conservation_system/features/incidents/domain/incident_categories.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';
import 'package:wildlife_conservation_system/shared/services/location_service.dart';

import '../helpers.dart';

class _MockLocationService extends Mock implements LocationService {}

class _Writer implements RemoteWriter {
  final Map<String, Map<String, dynamic>> documents = {};

  @override
  Future<void> upsert(
      String collection, String id, Map<String, dynamic> data) async {
    documents['$collection/$id'] = data;
  }
}

void main() {
  late _MockLocationService location;

  setUp(() {
    location = _MockLocationService();
    when(() => location.getCurrentPosition()).thenAnswer(
      (_) async => (latitude: 8.0312, longitude: 80.8971),
    );
  });

  ProviderContainer containerFor({
    required bool online,
    required FakeStorageService storage,
    required _Writer writer,
  }) {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
      locationServiceProvider.overrideWithValue(location),
      connectivityServiceProvider
          .overrideWithValue(FakeConnectivityService(online: online)),
      storageServiceProvider.overrideWithValue(storage),
      remoteWriterProvider.overrideWithValue(writer),
    ]);
    addTearDown(container.dispose);
    container.read(currentUserProvider.notifier).signIn(
          const AppUser(
            id: 'R001',
            name: 'Test Ranger',
            parkId: 'PARK-MIN',
            role: UserRole.ranger,
          ),
        );
    return container;
  }

  Future<void> seedPatrol(ProviderContainer container) async {
    final db = container.read(appDatabaseProvider);
    await db.into(db.patrolsTable).insert(
          PatrolsTableCompanion.insert(
            id: 'patrol-live',
            routeId: 'route-minneriya',
            rangerId: 'R001',
            parkId: 'PARK-MIN',
            scheduledFor: DateTime.utc(2026, 10, 8),
            assignedAt: DateTime.utc(2026, 10, 8),
            status: const Value('inProgress'),
          ),
        );
  }

  Future<void> fill(ProviderContainer container) async {
    final form = container.read(incidentFormControllerProvider.notifier);
    form.selectCategory(IncidentReportCategory.snare);
    form.setEvidence(
      CapturedEvidence(
        localPath: '/tmp/snare.jpg',
        filename: 'snare.jpg',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    );
    await form.captureGpsLocation();
    form.setDescription('Wire snare found beside animal trail.');
  }

  test('online report is stored once for the ranger and active patrol', () async {
    final storage = FakeStorageService();
    final writer = _Writer();
    final container = containerFor(online: true, storage: storage, writer: writer);
    await seedPatrol(container);
    await fill(container);

    final ok = await container.read(incidentSubmissionProvider.notifier).submit();

    expect(ok, isTrue);
    final submission = container.read(incidentSubmissionProvider);
    expect(submission.status, SubmissionPhase.synchronized);
    final stored = await container
        .read(incidentRepositoryProvider)
        .getIncident(submission.reportId!);
    expect(stored!.category, IncidentCategory.poaching);
    expect(stored.rangerId, 'R001');
    expect(stored.patrolId, 'patrol-live');
    expect(stored.latitude, 8.0312);
    expect(stored.description, contains('animal trail'));
    expect(stored.syncState, SyncState.synchronized);
    expect(storage.objects, isNotEmpty);
    expect(writer.documents.length, 1);
  });

  test('offline report stays pending and a second submit is not required to retry',
      () async {
    final storage = FakeStorageService();
    final container =
        containerFor(online: false, storage: storage, writer: _Writer());
    await seedPatrol(container);
    await fill(container);

    final ok = await container.read(incidentSubmissionProvider.notifier).submit();

    expect(ok, isTrue);
    final submission = container.read(incidentSubmissionProvider);
    expect(submission.status, SubmissionPhase.savedOffline);
    final stored = await container
        .read(incidentRepositoryProvider)
        .getIncident(submission.reportId!);
    expect(stored!.syncState, SyncState.pending);
    expect(stored.patrolId, 'patrol-live');
    final pending = await container
        .read(incidentLocalDataSourceProvider)
        .getPendingIncidents(rangerId: 'R001');
    expect(pending, hasLength(1));
  });
}

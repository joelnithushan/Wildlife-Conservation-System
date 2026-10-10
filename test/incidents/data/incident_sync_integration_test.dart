import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/constants/firestore_collections.dart';
import 'package:wildlife_conservation_system/core/sync/drift_local_sync_store.dart';
import 'package:wildlife_conservation_system/core/sync/remote_writers.dart';
import 'package:wildlife_conservation_system/core/sync/sync_service.dart';
import 'package:wildlife_conservation_system/features/incidents/data/datasources/incident_local_data_source.dart';
import 'package:wildlife_conservation_system/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:wildlife_conservation_system/shared/models/incident_report.dart';

import '../helpers.dart';

/// Remote writer that fails while [failuresRemaining] > 0 — models a dropped
/// connection. Otherwise delegates to an idempotent in-memory writer.
class FlakyIncidentRemoteWriter implements RemoteWriter {
  FlakyIncidentRemoteWriter(this.inner, {this.failuresRemaining = 0});
  final InMemoryRemoteWriter inner;
  int failuresRemaining;

  @override
  Future<void> upsert(
      String collection, String id, Map<String, dynamic> data) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw Exception('offline');
    }
    return inner.upsert(collection, id, data);
  }
}

void main() {
  late AppDatabase db;
  late IncidentLocalDataSource local;
  late IncidentRepositoryImpl repo;
  late DriftLocalSyncStore store;
  final now = DateTime.utc(2026, 9, 23, 8);

  setUp(() {
    db = createIncidentTestDatabase();
    local = IncidentLocalDataSource(db);
    store = DriftLocalSyncStore(db);
    repo = IncidentRepositoryImpl(local);
  });

  tearDown(() => db.close());

  Future<void> seedSubmittedReport(String id) async {
    await repo.createIncident(IncidentReport(
      id: id,
      rangerId: 'R001',
      parkId: 'PARK-MIN',
      category: IncidentCategory.snare,
      description: 'Wire snare near the river crossing',
      observedAt: now,
      latitude: 8.03,
      longitude: 80.89,
      locationSource: LocationSource.gps,
      localPhotoPath: '/tmp/evidence.jpg',
      submissionStatus: SubmissionStatus.submitted,
      reviewStatus: ReviewStatus.pendingReview,
      syncState: SyncState.pending,
      createdAt: now,
    ));
  }

  test('offline submission stays pending locally (no false synchronized)',
      () async {
    await seedSubmittedReport('incident_off');

    final pending = await repo.getPendingIncidents();
    expect(pending, hasLength(1));
    expect(pending.single.syncState, SyncState.pending);
    expect(pending.single.submissionStatus, SubmissionStatus.submitted);
  });

  test('sync success marks the incident synchronized and upserts remotely',
      () async {
    await seedSubmittedReport('incident_sync');
    final remote = InMemoryRemoteWriter();
    final service = DefaultSyncService(store: store, remote: remote);

    final summary = await service.syncPendingIncidentData();

    expect(summary.pushed, 1);
    expect(summary.failed, 0);
    expect(remote.documentCount, 1);
    final stored = await repo.getIncident('incident_sync');
    expect(stored!.syncState, SyncState.synchronized);
    await service.dispose();
  });

  test('sync payload carries the full incident wire map (evidence included)',
      () async {
    await seedSubmittedReport('incident_payload');
    final remote = InMemoryRemoteWriter();
    final service = DefaultSyncService(store: store, remote: remote);

    await service.syncPendingIncidentData();

    final doc = remote.documents['${FirestoreCollections.incidentReports}/'
        'incident_payload'];
    expect(doc, isNotNull);
    expect(doc!['description'], 'Wire snare near the river crossing');
    expect(doc['localPhotoPath'], '/tmp/evidence.jpg');
    expect(doc['submissionStatus'], SubmissionStatus.submitted.wire);
    expect(doc['reviewStatus'], ReviewStatus.pendingReview.wire);
    await service.dispose();
  });

  test('sync failure keeps the local record and marks it failed', () async {
    await seedSubmittedReport('incident_fail');
    final remote = FlakyIncidentRemoteWriter(
        InMemoryRemoteWriter(), failuresRemaining: 99);
    final service = DefaultSyncService(store: store, remote: remote);

    final summary = await service.syncPendingIncidentData();

    expect(summary.failed, 1);
    final stored = await repo.getIncident('incident_fail');
    expect(stored, isNotNull); // data retained
    expect(stored!.syncState, SyncState.failed);
    await service.dispose();
  });

  test('retry after failure reuses the same stable ID – no duplicate incident',
      () async {
    await seedSubmittedReport('incident_retry');
    final inner = InMemoryRemoteWriter();
    final remote = FlakyIncidentRemoteWriter(inner, failuresRemaining: 1);
    final service = DefaultSyncService(store: store, remote: remote);

    // First pass fails.
    final first = await service.syncPendingIncidentData();
    expect(first.failed, 1);
    expect(inner.documentCount, 0);

    // Retry eligibility: failed -> pending again (retry flow).
    await local.setSyncState('incident_retry', SyncState.pending);

    // Second pass succeeds.
    final second = await service.syncPendingIncidentData();
    expect(second.pushed, 1);
    expect(inner.documentCount, 1); // exactly one remote document
    final stored = await repo.getIncident('incident_retry');
    expect(stored!.syncState, SyncState.synchronized);
    await service.dispose();
  });

  test('failed incident auto-retries on the next sync run (no manual reset)',
      () async {
    await seedSubmittedReport('incident_autoretry');
    final inner = InMemoryRemoteWriter();
    // First pass fails (offline); second pass is back online.
    final remote = FlakyIncidentRemoteWriter(inner, failuresRemaining: 1);
    final service = DefaultSyncService(store: store, remote: remote);

    // First pass leaves the record marked failed.
    final first = await service.syncPendingIncidentData();
    expect(first.failed, 1);
    expect(inner.documentCount, 0);
    expect((await repo.getIncident('incident_autoretry'))!.syncState,
        SyncState.failed);

    // Second pass with NO manual reset — the store must re-queue the failed
    // record (§21 step 6) so it finally syncs with the same stable ID.
    final second = await service.syncPendingIncidentData();
    expect(second.pushed, 1, reason: 'failed record must be retried, not stranded');
    expect(inner.documentCount, 1); // no duplicate
    expect((await repo.getIncident('incident_autoretry'))!.syncState,
        SyncState.synchronized);
    await service.dispose();
  });

  test('double sync run never duplicates the remote incident', () async {
    await seedSubmittedReport('incident_twice');
    final remote = InMemoryRemoteWriter();
    final service = DefaultSyncService(store: store, remote: remote);

    await service.syncPendingIncidentData();
    final second = await service.syncPendingIncidentData();

    expect(second.pushed, 0); // nothing pending anymore
    expect(remote.documentCount, 1);
    await service.dispose();
  });

  test('two incidents sync as two documents (ids are not conflated)',
      () async {
    await seedSubmittedReport('incident_a');
    await seedSubmittedReport('incident_b');
    final remote = InMemoryRemoteWriter();
    final service = DefaultSyncService(store: store, remote: remote);

    final summary = await service.syncPendingIncidentData();

    expect(summary.pushed, 2);
    expect(remote.documentCount, 2);
    await service.dispose();
  });

  test('synchronized report enters the review queue; failed does not',
      () async {
    await seedSubmittedReport('incident_inqueue');
    await seedSubmittedReport('incident_notyet');
    final remote = FlakyIncidentRemoteWriter(
        InMemoryRemoteWriter(), failuresRemaining: 99);
    final service = DefaultSyncService(store: store, remote: remote);
    await service.syncPendingIncidentData();
    await service.dispose();

    // Mark the first record synchronized (as a successful sync would).
    await local.setSyncState('incident_inqueue', SyncState.synchronized);

    final queue = await repo.getIncidentsForReview('PARK-MIN');
    expect(queue.map((r) => r.id), ['incident_inqueue']);
  });
}

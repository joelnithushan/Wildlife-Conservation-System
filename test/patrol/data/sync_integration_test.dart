import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/sync/drift_local_sync_store.dart';
import 'package:wildlife_conservation_system/core/sync/remote_writers.dart';
import 'package:wildlife_conservation_system/core/sync/sync_service.dart';
import 'package:wildlife_conservation_system/features/patrol/data/datasources/patrol_local_data_source.dart';
import 'package:wildlife_conservation_system/features/patrol/data/repositories/patrol_repository_impl.dart';
import 'package:wildlife_conservation_system/shared/models/patrol_position.dart';

import '../helpers.dart';

/// Remote writer that fails a configurable number of times, then succeeds —
/// models transient connectivity loss.
class FlakyRemoteWriter implements RemoteWriter {
  FlakyRemoteWriter(this.inner, {this.failuresRemaining = 0});
  final InMemoryRemoteWriter inner;
  int failuresRemaining;

  @override
  Future<void> upsert(String collection, String id, Map<String, dynamic> data) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw Exception('offline');
    }
    return inner.upsert(collection, id, data);
  }
}

void main() {
  late AppDatabase db;
  late PatrolLocalDataSource local;
  late PatrolRepositoryImpl repo;
  late DriftLocalSyncStore store;
  final now = DateTime.utc(2026, 9, 23, 8);

  setUp(() {
    db = createTestDatabase();
    local = PatrolLocalDataSource(db);
    store = DriftLocalSyncStore(db);
    repo = PatrolRepositoryImpl(
      local: local,
      resolveRoute: testRouteResolver,
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  Future<String> assignedPatrolWithPosition() async {
    final patrol = await repo.assignRoute(
      routeId: testRoute.id,
      rangerId: 'R001',
      parkId: 'PARK-MIN',
      scheduledFor: now,
    );
    await repo.startPatrol(patrol.id);
    await repo.savePosition(PatrolPosition.create(
      patrolId: patrol.id,
      latitude: 8.03,
      longitude: 80.89,
      timestamp: now,
    ));
    return patrol.id;
  }

  test('offline position stays pending until synced', () async {
    await assignedPatrolWithPosition();
    final pending = await local.getPendingPositions();
    expect(pending, isNotEmpty);
    expect(pending.every((p) => p.syncState == SyncState.pending), isTrue);
  });

  test('sync success pushes patrol + positions and marks synchronized', () async {
    final id = await assignedPatrolWithPosition();
    final remote = InMemoryRemoteWriter();
    final service = DefaultSyncService(store: store, remote: remote);

    final summary = await service.syncPendingPatrolData();

    // 1 patrol + 1 position pushed.
    expect(summary.pushed, 2);
    expect(summary.failed, 0);
    expect(remote.documentCount, 2);
    expect((await local.getPatrolById(id))!.syncState, SyncState.synchronized);
    expect((await local.getPendingPositions()), isEmpty);
    await service.dispose();
  });

  test('sync failure marks records failed and keeps data locally', () async {
    await assignedPatrolWithPosition();
    final remote = FlakyRemoteWriter(InMemoryRemoteWriter(), failuresRemaining: 99);
    final service = DefaultSyncService(store: store, remote: remote);

    final summary = await service.syncPendingPatrolData();
    expect(summary.failed, greaterThan(0));
    // Data is not lost — rows still exist, marked failed.
    final patrols = await db.select(db.patrolsTable).get();
    expect(patrols.single.syncState, SyncState.failed.wire);
    await service.dispose();
  });

  test('connectivity-restored retry with same IDs creates NO duplicates',
      () async {
    final id = await assignedPatrolWithPosition();
    final inner = InMemoryRemoteWriter();
    // Fail every write on the first pass (2 records), then succeed.
    final remote = FlakyRemoteWriter(inner, failuresRemaining: 2);
    final service = DefaultSyncService(store: store, remote: remote);

    // First pass: offline -> both fail.
    final first = await service.syncPendingPatrolData();
    expect(first.failed, 2);
    expect(inner.documentCount, 0);

    // Records are failed but still pending-eligible for retry.
    await local.setPatrolSyncState(id, SyncState.pending);
    for (final p in await local.getPositions(id)) {
      await local.setPositionSyncState(p.id, SyncState.pending);
    }

    // Second pass: back online -> succeeds, same stable IDs.
    final second = await service.syncPendingPatrolData();
    expect(second.pushed, 2);
    // Exactly 2 documents total — retry did not duplicate.
    expect(inner.documentCount, 2);
    await service.dispose();
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/constants/firestore_collections.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/sync/sync_service.dart';

/// In-memory remote keyed by "collection/id" — models Firestore's idempotent
/// set-with-merge on a document ID.
class FakeRemoteWriter implements RemoteWriter {
  final Map<String, Map<String, dynamic>> docs = {};
  bool failNext = false;

  @override
  Future<void> upsert(String collection, String id, Map<String, dynamic> data) async {
    if (failNext) {
      failNext = false;
      throw Exception('network error');
    }
    docs['$collection/$id'] = data;
  }
}

/// In-memory local store that hands out pending items and records their state.
class FakeLocalStore implements LocalSyncStore {
  FakeLocalStore(this._patrolItems);

  final List<SyncItem> _patrolItems;
  final Map<String, SyncState> states = {};

  @override
  Future<List<SyncItem>> pendingPatrolItems() async =>
      _patrolItems.where((i) => states[i.id] != SyncState.synchronized).toList();

  @override
  Future<List<SyncItem>> pendingIncidentItems() async => const [];

  @override
  Future<void> markState(SyncItem item, SyncState state) async {
    states[item.id] = state;
  }
}

void main() {
  SyncItem patrolItem(String id) =>
      SyncItem(collection: FirestoreCollections.patrols, id: id, data: {'id': id});

  group('DefaultSyncService', () {
    test('success pushes records and marks them synchronized', () async {
      final remote = FakeRemoteWriter();
      final store = FakeLocalStore([patrolItem('p1'), patrolItem('p2')]);
      final service = DefaultSyncService(store: store, remote: remote);

      final summary = await service.syncPendingPatrolData();

      expect(summary.pushed, 2);
      expect(summary.failed, 0);
      expect(remote.docs.length, 2);
      expect(store.states['p1'], SyncState.synchronized);
      expect(store.states['p2'], SyncState.synchronized);
      await service.dispose();
    });

    test('failure marks the record failed and reports it', () async {
      final remote = FakeRemoteWriter()..failNext = true;
      final store = FakeLocalStore([patrolItem('p1')]);
      final service = DefaultSyncService(store: store, remote: remote);

      final summary = await service.syncPendingPatrolData();

      expect(summary.pushed, 0);
      expect(summary.failed, 1);
      expect(store.states['p1'], SyncState.failed);
      expect(summary.hasFailures, isTrue);
      await service.dispose();
    });

    test('retrying the same pending record does NOT create a duplicate', () async {
      final remote = FakeRemoteWriter();
      // First attempt fails, leaving p1 pending; second attempt succeeds.
      final store = FakeLocalStore([patrolItem('p1')]);
      final service = DefaultSyncService(store: store, remote: remote);

      remote.failNext = true;
      final first = await service.syncPendingPatrolData();
      expect(first.failed, 1);
      expect(store.states['p1'], SyncState.failed);

      final second = await service.syncPendingPatrolData();
      expect(second.pushed, 1);

      // Same stable ID upserted twice -> exactly one remote document.
      expect(remote.docs.length, 1);
      expect(remote.docs.containsKey('${FirestoreCollections.patrols}/p1'), isTrue);
      expect(store.states['p1'], SyncState.synchronized);
      await service.dispose();
    });
  });
}

import 'dart:async';

import '../enums/app_enums.dart';

/// Progress phase of a sync run (distinct from the record-level [SyncState]).
enum SyncPhase { idle, syncing, done, failed }

/// One record queued for synchronization. [id] is the stable client ID and is
/// used as the remote document ID so retries upsert the same document.
class SyncItem {
  const SyncItem({
    required this.collection,
    required this.id,
    required this.data,
  });

  final String collection;
  final String id;
  final Map<String, dynamic> data;
}

/// Result of a sync run.
class SyncSummary {
  const SyncSummary({this.pushed = 0, this.failed = 0});

  final int pushed;
  final int failed;

  bool get hasFailures => failed > 0;

  SyncSummary operator +(SyncSummary other) =>
      SyncSummary(pushed: pushed + other.pushed, failed: failed + other.failed);
}

/// Idempotent remote writer. [upsert] MUST write to a document keyed by [id]
/// (set-with-merge semantics) so retrying the same record never creates a
/// duplicate.
abstract interface class RemoteWriter {
  Future<void> upsert(String collection, String id, Map<String, dynamic> data);
}

/// Local source of pending records and the place their [SyncState] is updated.
abstract interface class LocalSyncStore {
  Future<List<SyncItem>> pendingPatrolItems();
  Future<List<SyncItem>> pendingIncidentItems();
  Future<void> markState(SyncItem item, SyncState state);
}

/// Shared offline-first sync contract.
abstract interface class SyncService {
  Future<SyncSummary> syncPendingPatrolData();
  Future<SyncSummary> syncPendingIncidentData();
  Future<SyncSummary> syncAllPendingData();
  Stream<SyncPhase> get phase;
}

/// Default sync service: reads pending local records and upserts them remotely
/// using their stable IDs. Marks each record [SyncState.synchronized] only on
/// success and [SyncState.failed] on error, leaving it eligible for retry.
class DefaultSyncService implements SyncService {
  DefaultSyncService({required LocalSyncStore store, required RemoteWriter remote})
      : _store = store,
        _remote = remote;

  final LocalSyncStore _store;
  final RemoteWriter _remote;

  final _phase = StreamController<SyncPhase>.broadcast();
  SyncPhase _currentPhase = SyncPhase.idle;

  SyncPhase get currentPhase => _currentPhase;

  @override
  Stream<SyncPhase> get phase => _phase.stream;

  void _emit(SyncPhase next) {
    _currentPhase = next;
    if (!_phase.isClosed) _phase.add(next);
  }

  /// Releases the phase stream. Call when the service is disposed.
  Future<void> dispose() => _phase.close();

  @override
  Future<SyncSummary> syncPendingPatrolData() =>
      _run(_store.pendingPatrolItems);

  @override
  Future<SyncSummary> syncPendingIncidentData() =>
      _run(_store.pendingIncidentItems);

  @override
  Future<SyncSummary> syncAllPendingData() async {
    final patrols = await syncPendingPatrolData();
    final incidents = await syncPendingIncidentData();
    return patrols + incidents;
  }

  Future<SyncSummary> _run(Future<List<SyncItem>> Function() fetch) async {
    _emit(SyncPhase.syncing);
    var pushed = 0;
    var failed = 0;
    try {
      final items = await fetch();
      for (final item in items) {
        try {
          // Idempotent: keyed on the stable client ID.
          await _remote.upsert(item.collection, item.id, item.data);
          await _store.markState(item, SyncState.synchronized);
          pushed++;
        } catch (_) {
          await _store.markState(item, SyncState.failed);
          failed++;
        }
      }
      _emit(failed > 0 ? SyncPhase.failed : SyncPhase.done);
    } catch (_) {
      _emit(SyncPhase.failed);
      rethrow;
    }
    return SyncSummary(pushed: pushed, failed: failed);
  }
}

/// Offline-first sync contract.
/// Each feature's repository registers its pending records here.
/// The concrete implementation reads SyncStatus.pending rows from Drift
/// and pushes them to Firestore when connectivity is restored.
abstract class SyncService {
  Future<void> syncPendingData();
  Stream<SyncState> get syncStateStream;
}

enum SyncState { idle, syncing, done, failed }

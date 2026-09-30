import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/sync/drift_local_sync_store.dart';
import '../../core/sync/remote_writers.dart';
import '../../core/sync/sync_service.dart';
import '../services/geolocator_location_service.dart';
import '../services/location_service.dart';

/// Shared, feature-agnostic providers.
///
/// Feature-specific state stays in each feature module. Repository
/// implementations are provided on their feature branches by overriding the
/// interface providers declared here.
///
/// Re-exported for convenience:
export '../session/current_user.dart' show currentUserProvider, CurrentUserNotifier;

/// Connectivity abstraction (backed by connectivity_plus).
final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityPlusService(),
);

/// Live online/offline status. Defaults to `true` until the first event.
final isOnlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).connectionChanges,
);

/// Whether Firebase initialized successfully at startup. Overridden in `main()`
/// with the real result of [bootstrapFirebase]. Defaults to `false` so tests and
/// unconfigured runs use local/in-memory infrastructure.
final firebaseReadyProvider = Provider<bool>((_) => false);

/// File storage. Uses Firebase Storage when Firebase is ready, otherwise a no-op
/// implementation so the app still runs without configuration.
final storageServiceProvider = Provider<StorageService>((ref) {
  return ref.watch(firebaseReadyProvider)
      ? FirebaseStorageService()
      : const UnavailableStorageService();
});

/// Shared location abstraction (backed by geolocator). Used by UC01 patrol
/// tracking and UC02 incident location capture.
final locationServiceProvider = Provider<LocationService>(
  (_) => const GeolocatorLocationService(),
);

/// Remote writer for sync. Uses [FirestoreRemoteWriter] when Firebase is
/// configured/initialized; otherwise an in-memory writer so the app still runs
/// and the sync flow is demonstrable without Firebase. Both are idempotent
/// (upsert keyed by the record's stable ID → retries never duplicate).
final remoteWriterProvider = Provider<RemoteWriter>((ref) {
  return ref.watch(firebaseReadyProvider)
      ? FirestoreRemoteWriter()
      : InMemoryRemoteWriter();
});

/// Local source of pending records for the sync engine.
final localSyncStoreProvider = Provider<LocalSyncStore>(
  (ref) => DriftLocalSyncStore(ref.watch(appDatabaseProvider)),
);

/// Shared offline-first sync engine (patrol + incident records).
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = DefaultSyncService(
    store: ref.watch(localSyncStoreProvider),
    remote: ref.watch(remoteWriterProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

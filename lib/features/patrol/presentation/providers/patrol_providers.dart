import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/sync/drift_local_sync_store.dart';
import '../../../../core/sync/remote_writers.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/patrol.dart';
import '../../../../shared/models/patrol_position.dart';
import '../../../../shared/models/patrol_route.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/repositories/patrol_repository.dart';
import '../../../../shared/services/geolocator_location_service.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../data/datasources/patrol_local_data_source.dart';
import '../../data/repositories/patrol_repository_impl.dart';

/// All patrol routes available for assignment (demo seed).
final patrolRoutesProvider = Provider<List<PatrolRoute>>((_) => DemoData.routes);

PatrolRoute? _routeById(String id) {
  for (final route in DemoData.routes) {
    if (route.id == id) return route;
  }
  return null;
}

/// Rangers who can be assigned patrols: available **rangers** in the
/// authenticated user's park only. A Park Manager never sees rangers from
/// another park, and only rangers (not liaison officers) are assignable.
final availableRangersProvider = Provider<List<AppUser>>((ref) {
  final parkId = ref.watch(currentUserProvider).parkId;
  return DemoData.users
      .where((u) =>
          u.role == UserRole.ranger && u.isAvailable && u.parkId == parkId)
      .toList();
});

final _localDataSourceProvider = Provider<PatrolLocalDataSource>(
  (ref) => PatrolLocalDataSource(ref.watch(appDatabaseProvider)),
);

/// Concrete offline-first patrol repository.
final patrolRepositoryProvider = Provider<PatrolRepository>(
  (ref) => PatrolRepositoryImpl(
    local: ref.watch(_localDataSourceProvider),
    resolveRoute: _routeById,
  ),
);

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

final _localSyncStoreProvider = Provider<LocalSyncStore>(
  (ref) => DriftLocalSyncStore(ref.watch(appDatabaseProvider)),
);

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = DefaultSyncService(
    store: ref.watch(_localSyncStoreProvider),
    remote: ref.watch(remoteWriterProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Patrols assigned to the current ranger (or a given ranger id).
final assignedPatrolsProvider =
    FutureProvider.family<List<Patrol>, String>((ref, rangerId) {
  return ref.watch(patrolRepositoryProvider).getAssignedPatrols(rangerId);
});

/// Patrols for the currently signed-in user.
final myPatrolsProvider = FutureProvider<List<Patrol>>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(assignedPatrolsProvider(user.id).future);
});

/// A single patrol by id.
final patrolByIdProvider =
    FutureProvider.family<Patrol?, String>((ref, id) {
  return ref.watch(patrolRepositoryProvider).getPatrolById(id);
});

/// Recorded positions for a patrol.
final patrolPositionsProvider =
    FutureProvider.family<List<PatrolPosition>, String>((ref, patrolId) {
  return ref.watch(patrolRepositoryProvider).getPositions(patrolId);
});

/// Total records still awaiting sync (patrols + positions).
final pendingRecordCountProvider = FutureProvider<int>((ref) async {
  final ds = ref.watch(_localDataSourceProvider);
  final patrols = await ds.getPendingPatrols();
  final positions = await ds.getPendingPositions();
  return patrols.length + positions.length;
});

/// Invalidate patrol-related providers after a mutation so the UI refreshes.
void refreshPatrolData(WidgetRef ref) {
  ref.invalidate(assignedPatrolsProvider);
  ref.invalidate(myPatrolsProvider);
  ref.invalidate(patrolByIdProvider);
  ref.invalidate(patrolPositionsProvider);
  ref.invalidate(pendingRecordCountProvider);
}

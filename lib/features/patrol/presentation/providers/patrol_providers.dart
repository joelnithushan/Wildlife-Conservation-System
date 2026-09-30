import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/models/patrol.dart';
import '../../../../shared/models/patrol_position.dart';
import '../../../../shared/models/patrol_route.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/repositories/patrol_repository.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../data/datasources/patrol_local_data_source.dart';
import '../../data/repositories/patrol_repository_impl.dart';

// locationServiceProvider, remoteWriterProvider, syncServiceProvider and the
// local sync store were moved to `shared/providers/providers.dart` so features
// other than patrol (UC02) can reuse them without cross-feature imports.
// Re-exported here so all existing patrol call sites keep working.
export '../../../../shared/providers/providers.dart'
    show locationServiceProvider, remoteWriterProvider, syncServiceProvider;

/// All patrol routes available for assignment (demo seed).
final patrolRoutesProvider = Provider<List<PatrolRoute>>((_) => DemoData.routes);

PatrolRoute? _routeById(String id) {
  for (final route in DemoData.routes) {
    if (route.id == id) return route;
  }
  return null;
}

/// Rangers who can be assigned patrols (available only).
final availableRangersProvider = Provider((_) =>
    DemoData.users.where((u) => u.isResponder && u.isAvailable).toList());

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

/// Remote writer for sync lives in `shared/providers/providers.dart` now.

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

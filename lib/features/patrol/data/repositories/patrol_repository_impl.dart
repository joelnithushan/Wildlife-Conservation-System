import '../../../../core/enums/app_enums.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../shared/models/patrol.dart';
import '../../../../shared/models/patrol_position.dart';
import '../../../../shared/models/patrol_route.dart';
import '../../../../shared/repositories/patrol_repository.dart';
import '../../domain/usecases/calculate_coverage.dart';
import '../datasources/patrol_local_data_source.dart';

/// Offline-first [PatrolRepository]. All writes persist locally first with
/// [SyncState.pending]; the SyncService pushes them to the backend later.
/// Status transitions are enforced here (not just in the UI).
class PatrolRepositoryImpl implements PatrolRepository {
  PatrolRepositoryImpl({
    required PatrolLocalDataSource local,
    required PatrolRoute? Function(String routeId) resolveRoute,
    DateTime Function() clock = DateTime.now,
    CalculateCoverage coverage = const CalculateCoverage(),
  })  : _local = local,
        _resolveRoute = resolveRoute,
        _now = clock,
        _coverage = coverage;

  final PatrolLocalDataSource _local;
  final PatrolRoute? Function(String routeId) _resolveRoute;
  final DateTime Function() _now;
  final CalculateCoverage _coverage;

  @override
  Future<List<Patrol>> getAssignedPatrols(String rangerId) =>
      _local.getAssignedPatrols(rangerId);

  @override
  Future<Patrol?> getPatrolById(String id) => _local.getPatrolById(id);

  @override
  Future<Patrol> assignRoute({
    required String routeId,
    required String rangerId,
    required String parkId,
    required DateTime scheduledFor,
  }) async {
    final now = _now();
    final patrol = Patrol(
      id: Patrol.create(
        routeId: routeId,
        rangerId: rangerId,
        parkId: parkId,
        scheduledFor: scheduledFor,
        assignedAt: now,
      ).id,
      routeId: routeId,
      rangerId: rangerId,
      parkId: parkId,
      scheduledFor: scheduledFor,
      assignedAt: now,
    );
    await _local.upsertPatrol(patrol, now: now);
    return patrol;
  }

  @override
  Future<Patrol> startPatrol(String id) async {
    final patrol = await _requirePatrol(id);
    if (!patrol.status.canTransitionTo(PatrolStatus.inProgress)) {
      throw ValidationException(
          'Cannot start a patrol with status ${patrol.status.name}.');
    }
    final now = _now();
    final updated = patrol.copyWith(
      status: PatrolStatus.inProgress,
      startedAt: now,
      syncState: SyncState.pending,
    );
    await _local.upsertPatrol(updated, now: now);
    return updated;
  }

  @override
  Future<void> savePosition(PatrolPosition position) =>
      _local.upsertPosition(position, now: _now());

  @override
  Future<List<PatrolPosition>> getPositions(String patrolId) =>
      _local.getPositions(patrolId);

  @override
  Future<Patrol> completePatrol(String id) async {
    final patrol = await _requirePatrol(id);
    if (!patrol.status.canTransitionTo(PatrolStatus.completed)) {
      throw ValidationException(
          'Cannot complete a patrol with status ${patrol.status.name}.');
    }
    final now = _now();
    final coverage = await calculateCoverage(id);
    final updated = patrol.copyWith(
      status: PatrolStatus.completed,
      completedAt: now,
      coveragePercent: coverage,
      syncState: SyncState.pending,
    );
    await _local.upsertPatrol(updated, now: now);
    return updated;
  }

  @override
  Future<double> calculateCoverage(String id) async {
    final patrol = await _requirePatrol(id);
    final route = _resolveRoute(patrol.routeId);
    if (route == null) return 0;
    final positions = await _local.getPositions(id);
    return _coverage(route, positions);
  }

  @override
  Future<List<Patrol>> getPendingPatrols() => _local.getPendingPatrols();

  Future<Patrol> _requirePatrol(String id) async {
    final patrol = await _local.getPatrolById(id);
    if (patrol == null) {
      throw RepositoryException('Patrol $id not found.');
    }
    return patrol;
  }
}

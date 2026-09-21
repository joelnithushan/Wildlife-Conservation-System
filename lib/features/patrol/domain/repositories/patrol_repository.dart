import '../entities/patrol.dart';
import '../entities/patrol_position.dart';

abstract class PatrolRepository {
  Future<List<Patrol>> getAssignedPatrols(String rangerId);
  Future<Patrol?> getPatrolById(String id);
  Future<void> savePatrol(Patrol patrol);
  Future<void> updatePatrolStatus(String patrolId, String status);
  Future<void> savePosition(PatrolPosition position);
  Future<List<PatrolPosition>> getPositionsForPatrol(String patrolId);
  Future<List<Patrol>> getPendingSyncPatrols();
}

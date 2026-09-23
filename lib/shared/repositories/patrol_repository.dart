import '../models/patrol.dart';
import '../models/patrol_position.dart';

/// Contract for UC01 – Manage Patrol Operations.
/// Implementations live behind the offline-first (Drift + Firestore) layer.
abstract interface class PatrolRepository {
  Future<List<Patrol>> getAssignedPatrols(String rangerId);
  Future<Patrol?> getPatrolById(String id);
  Future<Patrol> assignRoute({
    required String routeId,
    required String rangerId,
    required String parkId,
    required DateTime scheduledFor,
  });
  Future<Patrol> startPatrol(String id);
  Future<void> savePosition(PatrolPosition position);
  Future<List<PatrolPosition>> getPositions(String patrolId);
  Future<Patrol> completePatrol(String id);

  /// Returns coverage percentage (0–100) for a patrol.
  Future<double> calculateCoverage(String id);

  /// Locally-stored patrols/positions awaiting sync.
  Future<List<Patrol>> getPendingPatrols();
}

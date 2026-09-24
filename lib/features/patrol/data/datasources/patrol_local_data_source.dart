import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../shared/models/patrol.dart';
import '../../../../shared/models/patrol_position.dart';
import '../mappers/patrol_mappers.dart';

/// Offline-first local persistence for patrols and positions (Drift/SQLite).
/// This is the source of truth for field workflows; sync pushes from here.
class PatrolLocalDataSource {
  PatrolLocalDataSource(this._db);

  final AppDatabase _db;

  Future<List<Patrol>> getAssignedPatrols(String rangerId) async {
    try {
      final query = _db.select(_db.patrolsTable)
        ..where((t) => t.rangerId.equals(rangerId))
        ..orderBy([(t) => OrderingTerm.asc(t.scheduledFor)]);
      final rows = await query.get();
      return rows.map((r) => r.toDomain()).toList();
    } catch (e) {
      throw LocalStorageException('Failed to read patrols: $e');
    }
  }

  Future<Patrol?> getPatrolById(String id) async {
    final row = await (_db.select(_db.patrolsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  Future<void> upsertPatrol(Patrol patrol, {required DateTime now}) async {
    try {
      await _db
          .into(_db.patrolsTable)
          .insertOnConflictUpdate(patrol.toCompanion(updatedAt: now));
    } catch (e) {
      throw LocalStorageException('Failed to save patrol: $e');
    }
  }

  Future<void> upsertPosition(PatrolPosition position,
      {required DateTime now}) async {
    try {
      await _db
          .into(_db.patrolPositionsTable)
          .insertOnConflictUpdate(position.toCompanion(updatedAt: now));
    } catch (e) {
      throw LocalStorageException('Failed to save position: $e');
    }
  }

  Future<List<PatrolPosition>> getPositions(String patrolId) async {
    final query = _db.select(_db.patrolPositionsTable)
      ..where((t) => t.patrolId.equals(patrolId))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    final rows = await query.get();
    return rows.map((r) => r.toDomain()).toList();
  }

  Future<List<Patrol>> getPendingPatrols() async {
    final query = _db.select(_db.patrolsTable)
      ..where((t) => t.syncState.equals(SyncState.pending.wire));
    final rows = await query.get();
    return rows.map((r) => r.toDomain()).toList();
  }

  Future<List<PatrolPosition>> getPendingPositions() async {
    final query = _db.select(_db.patrolPositionsTable)
      ..where((t) => t.syncState.equals(SyncState.pending.wire));
    final rows = await query.get();
    return rows.map((r) => r.toDomain()).toList();
  }

  Future<void> setPatrolSyncState(String id, SyncState state) async {
    await (_db.update(_db.patrolsTable)..where((t) => t.id.equals(id)))
        .write(PatrolsTableCompanion(syncState: Value(state.wire)));
  }

  Future<void> setPositionSyncState(String id, SyncState state) async {
    await (_db.update(_db.patrolPositionsTable)..where((t) => t.id.equals(id)))
        .write(PatrolPositionsTableCompanion(syncState: Value(state.wire)));
  }
}

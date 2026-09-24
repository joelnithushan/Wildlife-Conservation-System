import 'package:drift/drift.dart';

import '../constants/firestore_collections.dart';
import '../database/app_database.dart';
import '../enums/app_enums.dart';
import '../../features/patrol/data/mappers/patrol_mappers.dart';
import 'sync_service.dart';

/// [LocalSyncStore] backed by Drift. Surfaces pending patrol/position/incident
/// rows as [SyncItem]s (wire maps keyed by stable ID) and updates their
/// [SyncState] after a sync attempt.
class DriftLocalSyncStore implements LocalSyncStore {
  DriftLocalSyncStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<SyncItem>> pendingPatrolItems() async {
    final patrols = await (_db.select(_db.patrolsTable)
          ..where((t) => t.syncState.equals(SyncState.pending.wire)))
        .get();
    final positions = await (_db.select(_db.patrolPositionsTable)
          ..where((t) => t.syncState.equals(SyncState.pending.wire)))
        .get();

    return [
      for (final row in patrols)
        SyncItem(
          collection: FirestoreCollections.patrols,
          id: row.id,
          data: row.toDomain().toMap(),
        ),
      for (final row in positions)
        SyncItem(
          collection: FirestoreCollections.patrolPositions,
          id: row.id,
          data: row.toDomain().toMap(),
        ),
    ];
  }

  @override
  Future<List<SyncItem>> pendingIncidentItems() async {
    final incidents = await (_db.select(_db.incidentReportsTable)
          ..where((t) => t.syncState.equals(SyncState.pending.wire)))
        .get();
    return [
      for (final row in incidents)
        SyncItem(
          collection: FirestoreCollections.incidentReports,
          id: row.id,
          data: row.toJson(),
        ),
    ];
  }

  @override
  Future<void> markState(SyncItem item, SyncState state) async {
    switch (item.collection) {
      case FirestoreCollections.patrols:
        await (_db.update(_db.patrolsTable)..where((t) => t.id.equals(item.id)))
            .write(PatrolsTableCompanion(syncState: Value(state.wire)));
      case FirestoreCollections.patrolPositions:
        await (_db.update(_db.patrolPositionsTable)
              ..where((t) => t.id.equals(item.id)))
            .write(PatrolPositionsTableCompanion(syncState: Value(state.wire)));
      case FirestoreCollections.incidentReports:
        await (_db.update(_db.incidentReportsTable)
              ..where((t) => t.id.equals(item.id)))
            .write(IncidentReportsTableCompanion(syncState: Value(state.wire)));
    }
  }
}

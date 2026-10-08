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

  // A record is eligible for (re)sync when it is still pending OR a previous
  // attempt left it failed. Including failed rows is what makes §21 step 6
  // ("retry later using the SAME ID") actually happen on the next sync run —
  // otherwise a single transient failure strands the record forever.
  static final List<String> _retryableStates = [
    SyncState.pending.wire,
    SyncState.failed.wire,
  ];

  @override
  Future<List<SyncItem>> pendingPatrolItems() async {
    final patrols = await (_db.select(_db.patrolsTable)
          ..where((t) => t.syncState.isIn(_retryableStates)))
        .get();
    final positions = await (_db.select(_db.patrolPositionsTable)
          ..where((t) => t.syncState.isIn(_retryableStates)))
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
          ..where((t) => t.syncState.isIn(_retryableStates)))
        .get();
    return [
      for (final row in incidents)
        SyncItem(
          collection: FirestoreCollections.incidentReports,
          id: row.id,
          data: _incidentRowWire(row),
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

/// Wire map for a pending incident row. Drift data classes have no toJson;
/// the payload matches IncidentReport.toMap so sync upserts the domain record.
Map<String, dynamic> _incidentRowWire(IncidentReportsTableData row) => {
      'id': row.id,
      'rangerId': row.rangerId,
      'patrolId': row.patrolId,
      'parkId': row.parkId,
      'category': row.category,
      'description': row.description,
      'observedAt': row.observedAt.toUtc().toIso8601String(),
      'latitude': row.latitude,
      'longitude': row.longitude,
      'locationSource': row.locationSource,
      'localPhotoPath': row.localPhotoPath,
      'photoUrl': row.photoUrl,
      'evidenceOmissionReason': row.evidenceOmissionReason,
      'submissionStatus': row.submissionStatus,
      'reviewStatus': row.reviewStatus,
      'reviewerId': row.reviewerId,
      'reviewNotes': row.reviewNotes,
      'reviewedAt': row.reviewedAt?.toUtc().toIso8601String(),
      'syncState': row.syncState,
      'createdAt': row.createdAt.toUtc().toIso8601String(),
    };

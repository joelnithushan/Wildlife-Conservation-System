import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../shared/models/incident_report.dart';
import '../mappers/incident_mappers.dart';

/// Offline-first local persistence for incident reports (Drift/SQLite).
/// Source of truth for the field workflow; sync pushes from here.
class IncidentLocalDataSource {
  IncidentLocalDataSource(this._db);

  final AppDatabase _db;

  /// Inserts or updates by stable ID. Returns true when the write succeeded.
  Future<bool> upsertIncident(IncidentReport incident, {DateTime? now}) async {
    try {
      await _db
          .into(_db.incidentReportsTable)
          .insertOnConflictUpdate(incident.toCompanion(updatedAt: now));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<IncidentReport?> getIncidentById(String id) async {
    final row = await (_db.select(_db.incidentReportsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  /// Every report stored on this device, newest observation first.
  Future<List<IncidentReport>> getLocalIncidents() async {
    try {
      final query = _db.select(_db.incidentReportsTable)
        ..orderBy([(t) => OrderingTerm.desc(t.observedAt)]);
      final rows = await query.get();
      return rows.map((r) => r.toDomain()).toList();
    } catch (e) {
      throw LocalStorageException('Failed to read incidents: $e');
    }
  }

  /// This ranger's reports, newest observation first (Ranger "my reports" list).
  Future<List<IncidentReport>> getIncidentsByRanger(String rangerId) async {
    try {
      final query = _db.select(_db.incidentReportsTable)
        ..where((t) => t.rangerId.equals(rangerId))
        ..orderBy([(t) => OrderingTerm.desc(t.observedAt)]);
      final rows = await query.get();
      return rows.map((r) => r.toDomain()).toList();
    } catch (e) {
      throw LocalStorageException('Failed to read incidents: $e');
    }
  }

  /// Reports eligible for the central review queue.
  ///
  /// ONLY synchronized reports are returned — pending/failed local-only records
  /// have not reached the backend, so reviewers must not act on them.
  Future<List<IncidentReport>> getSynchronizedIncidents(String parkId) async {
    try {
      final query = _db.select(_db.incidentReportsTable)
        ..where((t) =>
            t.parkId.equals(parkId) &
            t.syncState.equals(SyncState.synchronized.wire))
        ..orderBy([(t) => OrderingTerm.desc(t.observedAt)]);
      final rows = await query.get();
      return rows.map((r) => r.toDomain()).toList();
    } catch (e) {
      throw LocalStorageException('Failed to read review queue: $e');
    }
  }

  /// Reports still awaiting synchronization. Pass [rangerId] to scope the
  /// result to one ranger's "my reports" view.
  Future<List<IncidentReport>> getPendingIncidents({String? rangerId}) async {
    try {
      final query = _db.select(_db.incidentReportsTable);
      if (rangerId != null) {
        query.where((t) =>
            t.rangerId.equals(rangerId) &
            t.syncState.equals(SyncState.pending.wire));
      } else {
        query.where((t) => t.syncState.equals(SyncState.pending.wire));
      }
      query.orderBy([(t) => OrderingTerm.desc(t.observedAt)]);
      final rows = await query.get();
      return rows.map((r) => r.toDomain()).toList();
    } catch (e) {
      throw LocalStorageException('Failed to read pending incidents: $e');
    }
  }

  /// Sets the sync state for one row (used by retry flows).
  Future<void> setSyncState(String id, SyncState state) async {
    await (_db.update(_db.incidentReportsTable)
          ..where((t) => t.id.equals(id)))
        .write(IncidentReportsTableCompanion(syncState: Value(state.wire)));
  }
}

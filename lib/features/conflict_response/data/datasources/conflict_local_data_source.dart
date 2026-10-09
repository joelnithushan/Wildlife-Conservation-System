import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../shared/models/alert_status_change.dart';
import '../../../../shared/models/community_report.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/models/response_assignment.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../mappers/conflict_mappers.dart';

/// Offline-first local persistence for conflict response (Drift/SQLite).
/// Ensures alerts, readings, assignments, status history, and community reports
/// survive application restarts.
class ConflictLocalDataSource {
  ConflictLocalDataSource(this._db);

  final AppDatabase _db;

  // --- Wildlife Risk Alerts -------------------------------------------------

  Future<bool> upsertAlert(WildlifeRiskAlert alert) async {
    try {
      await _db
          .into(_db.wildlifeRiskAlertsTable)
          .insertOnConflictUpdate(alert.toCompanion());
      return true;
    } catch (e) {
      throw LocalStorageException('Failed to save alert: $e');
    }
  }

  Future<WildlifeRiskAlert?> getAlertById(String id) async {
    final row = await (_db.select(_db.wildlifeRiskAlertsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  Future<List<WildlifeRiskAlert>> getAlertsByPark(String parkId) async {
    final rows = await (_db.select(_db.wildlifeRiskAlertsTable)
          ..where((t) => t.parkId.equals(parkId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  Future<List<WildlifeRiskAlert>> getAllAlerts() async {
    final rows = await (_db.select(_db.wildlifeRiskAlertsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  // --- Location Readings ----------------------------------------------------

  Future<bool> saveReading(LocationReading reading) async {
    try {
      await _db
          .into(_db.locationReadingsTable)
          .insertOnConflictUpdate(reading.toCompanion());
      return true;
    } catch (e) {
      throw LocalStorageException('Failed to save reading: $e');
    }
  }

  Future<List<LocationReading>> getAllReadings() async {
    final rows = await (_db.select(_db.locationReadingsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  // --- Response Assignments -------------------------------------------------

  Future<bool> upsertAssignment(ResponseAssignment assignment) async {
    try {
      await _db
          .into(_db.responseAssignmentsTable)
          .insertOnConflictUpdate(assignment.toCompanion());
      return true;
    } catch (e) {
      throw LocalStorageException('Failed to save assignment: $e');
    }
  }

  Future<ResponseAssignment?> getAssignmentById(String id) async {
    final row = await (_db.select(_db.responseAssignmentsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  Future<List<ResponseAssignment>> getAssignmentsForAlert(
      String alertId) async {
    final rows = await (_db.select(_db.responseAssignmentsTable)
          ..where((t) => t.alertId.equals(alertId))
          ..orderBy([(t) => OrderingTerm.asc(t.assignedAt)]))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  Future<ResponseAssignment?> getActiveAssignment(String alertId) async {
    final rows = await getAssignmentsForAlert(alertId);
    return rows.isEmpty ? null : rows.last;
  }

  // --- Alert Status Changes -------------------------------------------------

  Future<bool> saveStatusChange(AlertStatusChange change) async {
    try {
      await _db
          .into(_db.alertStatusChangesTable)
          .insertOnConflictUpdate(change.toCompanion());
      return true;
    } catch (e) {
      throw LocalStorageException('Failed to save status change: $e');
    }
  }

  Future<List<AlertStatusChange>> getStatusHistory(String alertId) async {
    final rows = await (_db.select(_db.alertStatusChangesTable)
          ..where((t) => t.alertId.equals(alertId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  // --- Community Reports ----------------------------------------------------

  Future<bool> upsertCommunityReport(CommunityReport report) async {
    try {
      await _db
          .into(_db.communityReportsTable)
          .insertOnConflictUpdate(report.toCompanion());
      return true;
    } catch (e) {
      throw LocalStorageException('Failed to save community report: $e');
    }
  }

  Future<CommunityReport?> getCommunityReportById(String id) async {
    final row = await (_db.select(_db.communityReportsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  Future<List<CommunityReport>> getCommunityReportsByPark(
      String parkId) async {
    final rows = await (_db.select(_db.communityReportsTable)
          ..where((t) => t.parkId.equals(parkId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }
}

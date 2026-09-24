import '../../../core/database/app_database.dart';
import '../../../core/errors/exceptions.dart';
import '../../../shared/models/incident_report.dart';
import '../../../shared/models/patrol.dart';
import '../../../shared/models/patrol_position.dart';
import '../domain/report_source_data.dart';
import 'report_read_store.dart';

/// Reads patrols, positions, and incidents with Drift `select` only.
///
/// Alert rows come from [alerts]. This store never writes source tables.
class DriftReportReadStore implements ReportReadStore {
  DriftReportReadStore(this._db, {required this.alerts});

  final AppDatabase _db;
  final AlertReadStore alerts;

  @override
  Future<ReportSourceData> load(String parkId) async {
    try {
      final patrolRows = await (_db.select(_db.patrolsTable)
            ..where((table) => table.parkId.equals(parkId)))
          .get();
      final patrols = <Patrol>[];
      for (final row in patrolRows) {
        final patrol = _patrolOrNull(row);
        if (patrol != null) patrols.add(patrol);
      }

      final ids = patrols.map((patrol) => patrol.id).toList();
      final positions = <PatrolPosition>[];
      if (ids.isNotEmpty) {
        final positionRows = await (_db.select(_db.patrolPositionsTable)
              ..where((table) => table.patrolId.isIn(ids)))
            .get();
        for (final row in positionRows) {
          final position = _positionOrNull(row);
          if (position != null) positions.add(position);
        }
      }

      final incidentRows = await (_db.select(_db.incidentReportsTable)
            ..where((table) => table.parkId.equals(parkId)))
          .get();
      final incidents = <IncidentReport>[];
      for (final row in incidentRows) {
        final incident = _incidentOrNull(row);
        if (incident != null) incidents.add(incident);
      }

      final alertRows = await alerts.load(parkId);
      return ReportSourceData(
        patrols: patrols,
        positions: positions,
        incidents: incidents,
        alerts: alertRows,
      );
    } on RepositoryException {
      rethrow;
    } catch (_) {
      throw const RepositoryException(
        'The data service is unavailable – no new report was created.',
      );
    }
  }

  Patrol? _patrolOrNull(PatrolsTableData row) {
    try {
      return Patrol.fromMap({
        'id': row.id,
        'routeId': row.routeId,
        'rangerId': row.rangerId,
        'parkId': row.parkId,
        'scheduledFor': row.scheduledFor,
        'status': row.status,
        'assignedAt': row.assignedAt,
        'startedAt': row.startedAt,
        'completedAt': row.completedAt,
        'coveragePercent': row.coveragePercent,
        'syncState': row.syncState,
      });
    } catch (_) {
      return null;
    }
  }

  PatrolPosition? _positionOrNull(PatrolPositionsTableData row) {
    try {
      return PatrolPosition.fromMap({
        'id': row.id,
        'patrolId': row.patrolId,
        'latitude': row.latitude,
        'longitude': row.longitude,
        'timestamp': row.timestamp,
        'captureMode': row.captureMode,
        'syncState': row.syncState,
      });
    } catch (_) {
      return null;
    }
  }

  IncidentReport? _incidentOrNull(IncidentReportsTableData row) {
    try {
      return IncidentReport.fromMap({
        'id': row.id,
        'rangerId': row.rangerId,
        'patrolId': row.patrolId,
        'parkId': row.parkId,
        'category': row.category,
        'description': row.description,
        'observedAt': row.observedAt,
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
        'reviewedAt': row.reviewedAt,
        'syncState': row.syncState,
        'createdAt': row.createdAt,
      });
    } catch (_) {
      return null;
    }
  }
}

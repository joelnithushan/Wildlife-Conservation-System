import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/errors/exceptions.dart';
import 'package:wildlife_conservation_system/shared/models/conservation_report.dart';
import 'package:wildlife_conservation_system/shared/models/incident_report.dart';
import 'package:wildlife_conservation_system/shared/models/patrol.dart';
import 'package:wildlife_conservation_system/shared/models/patrol_position.dart';
import 'package:wildlife_conservation_system/shared/models/report_criteria.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';
import 'package:wildlife_conservation_system/shared/repositories/report_export_service.dart';
import 'package:wildlife_conservation_system/shared/repositories/report_repository.dart';

ReportCriteria testCriteria({
  String parkId = 'PARK-MIN',
  DateTime? start,
  DateTime? end,
  List<IncidentCategory>? categories,
}) {
  return ReportCriteria(
    parkId: parkId,
    startDate: start ?? DateTime.utc(2026, 3, 1),
    endDate: end ?? DateTime.utc(2026, 3, 31),
    categories: categories ?? IncidentCategory.values,
  );
}

IncidentReport testIncident({
  required String id,
  IncidentCategory category = IncidentCategory.poaching,
  String parkId = 'PARK-MIN',
  DateTime? observedAt,
  SyncState syncState = SyncState.synchronized,
  double latitude = 8.03,
  double longitude = 80.89,
}) {
  return IncidentReport(
    id: id,
    rangerId: 'R001',
    parkId: parkId,
    category: category,
    description: 'Field note',
    observedAt: observedAt ?? DateTime.utc(2026, 3, 10),
    latitude: latitude,
    longitude: longitude,
    locationSource: LocationSource.gps,
    createdAt: DateTime.utc(2026, 3, 10),
    submissionStatus: SubmissionStatus.submitted,
    syncState: syncState,
  );
}

Patrol testPatrol({
  required String id,
  String parkId = 'PARK-MIN',
  PatrolStatus status = PatrolStatus.completed,
  SyncState syncState = SyncState.synchronized,
  DateTime? completedAt,
  DateTime? scheduledFor,
  double? coveragePercent = 80,
}) {
  final scheduled = scheduledFor ?? DateTime.utc(2026, 3, 4);
  return Patrol(
    id: id,
    routeId: 'RT-07',
    rangerId: 'R001',
    parkId: parkId,
    scheduledFor: scheduled,
    assignedAt: DateTime.utc(2026, 3, 1),
    status: status,
    completedAt: completedAt,
    coveragePercent: coveragePercent,
    syncState: syncState,
  );
}

PatrolPosition testPosition({
  required String id,
  required String patrolId,
  DateTime? timestamp,
  SyncState syncState = SyncState.pending,
}) {
  return PatrolPosition(
    id: id,
    patrolId: patrolId,
    latitude: 8.03,
    longitude: 80.89,
    timestamp: timestamp ?? DateTime.utc(2026, 3, 4, 9),
    syncState: syncState,
  );
}

WildlifeRiskAlert testAlert({
  required String id,
  String parkId = 'PARK-MIN',
  DateTime? createdAt,
  AlertStatus status = AlertStatus.newAlert,
}) {
  return WildlifeRiskAlert(
    id: id,
    parkId: parkId,
    source: AlertSource.collar,
    latitude: 8.04,
    longitude: 80.9,
    severity: AlertSeverity.high,
    createdAt: createdAt ?? DateTime.utc(2026, 3, 8),
    status: status,
  );
}

ConservationReport testReport({
  int totalPoaching = 4,
  double coverage = 80,
  int completedPatrols = 2,
  int openAlerts = 1,
  int resolvedAlerts = 1,
  int excluded = 3,
  String snapshotId = 'report-snap-1',
  DateTime? cutoff,
}) {
  final when = cutoff ?? DateTime.utc(2026, 4, 1, 8);
  return ConservationReport(
    snapshotId: snapshotId,
    criteria: testCriteria(),
    parkName: 'Minneriya National Park',
    incidentCounts: {
      for (final category in IncidentCategory.values)
        category: category == IncidentCategory.poaching ? totalPoaching : 0,
    },
    patrolCoverage: coverage,
    completedPatrolCount: completedPatrols,
    conflictTrends: [
      ConflictTrendPoint(
          periodStart: DateTime.utc(2026, 3, 2),
          count: openAlerts + resolvedAlerts),
    ],
    openAlertCount: openAlerts,
    resolvedAlertCount: resolvedAlerts,
    dataCutoff: when,
    excludedPendingCount: excluded,
    generatedAt: when,
  );
}

class ScriptedReportRepository implements ReportRepository {
  ScriptedReportRepository(this.results, {this.delay = Duration.zero});

  final List<Object> results;
  final Duration delay;
  int calls = 0;
  final List<ReportCriteria> criteriaSeen = [];

  @override
  Future<ConservationReport> generateReport(ReportCriteria criteria) async {
    criteriaSeen.add(criteria);
    final result = results[calls];
    calls++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (result is Exception) throw result;
    return result as ConservationReport;
  }
}

class RecordingExportService implements ReportExportService {
  ConservationReport? pdfReport;
  ConservationReport? csvReport;
  int calls = 0;
  Object? failure;

  @override
  Future<String> exportPdf(ConservationReport report) async {
    calls++;
    if (failure != null) throw failure!;
    pdfReport = report;
    return 'report.pdf';
  }

  @override
  Future<String> exportCsv(ConservationReport report) async {
    calls++;
    if (failure != null) throw failure!;
    csvReport = report;
    return 'report.csv';
  }
}

RepositoryException get dataServiceDown => const RepositoryException('down');

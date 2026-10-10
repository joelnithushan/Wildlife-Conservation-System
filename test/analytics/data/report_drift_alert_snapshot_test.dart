import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/analytics/data/drift_alert_read_store.dart';
import 'package:wildlife_conservation_system/features/analytics/data/drift_report_read_store.dart';
import 'package:wildlife_conservation_system/features/analytics/data/report_document_builder.dart';
import 'package:wildlife_conservation_system/features/analytics/data/report_export_service_impl.dart';
import 'package:wildlife_conservation_system/features/analytics/data/report_repository_impl.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/datasources/conflict_local_data_source.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';

import '../../patrol/helpers.dart';
import '../helpers.dart';

void main() {
  group('Report snapshot and export with Drift offline alerts', () {
    test('captures snapshot with Drift alerts and exports to PDF and CSV', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final reportStart = DateTime.utc(2026, 3, 1);
      final reportEnd = DateTime.utc(2026, 3, 31, 23, 59, 59);

      // Insert Drift incident
      await db.into(db.incidentReportsTable).insert(
            IncidentReportsTableCompanion(
              id: const Value('inc-1'),
              rangerId: const Value('R001'),
              parkId: const Value('PARK-MIN'),
              category: Value(IncidentCategory.snare.wire),
              description: const Value('Suspicious tracks near boundary'),
              observedAt: Value(DateTime.utc(2026, 3, 10, 9)),
              latitude: const Value(8.05),
              longitude: const Value(80.88),
              locationSource: Value(LocationSource.gps.wire),
              submissionStatus: Value(SubmissionStatus.submitted.wire),
              reviewStatus: Value(ReviewStatus.pendingReview.wire),
              syncState: Value(SyncState.synchronized.wire),
              createdAt: Value(DateTime.utc(2026, 3, 10, 9)),
            ),
          );

      // Insert Drift patrol
      await db.into(db.patrolsTable).insert(
            PatrolsTableCompanion(
              id: const Value('patrol-1'),
              routeId: const Value('RT-07'),
              rangerId: const Value('R001'),
              parkId: const Value('PARK-MIN'),
              scheduledFor: Value(DateTime.utc(2026, 3, 12)),
              status: Value(PatrolStatus.completed.wire),
              assignedAt: Value(DateTime.utc(2026, 3, 1)),
              completedAt: Value(DateTime.utc(2026, 3, 12, 17)),
              coveragePercent: const Value(88),
              syncState: Value(SyncState.synchronized.wire),
            ),
          );

      // Insert Drift wildlife risk alerts via ConflictLocalDataSource
      final conflictDataSource = ConflictLocalDataSource(db);

      // Active / acknowledged alert
      await conflictDataSource.upsertAlert(
        WildlifeRiskAlert(
          id: 'alert-drift-1',
          parkId: 'PARK-MIN',
          source: AlertSource.collar,
          latitude: 8.02,
          longitude: 80.91,
          severity: AlertSeverity.high,
          createdAt: DateTime.utc(2026, 3, 5, 14),
          status: AlertStatus.acknowledged,
        ),
      );

      // Resolved alert from community report
      await conflictDataSource.upsertAlert(
        WildlifeRiskAlert(
          id: 'alert-drift-2',
          parkId: 'PARK-MIN',
          source: AlertSource.communityReport,
          latitude: 8.06,
          longitude: 80.87,
          severity: AlertSeverity.medium,
          createdAt: DateTime.utc(2026, 3, 18, 10),
          status: AlertStatus.resolved,
          resolvedAt: DateTime.utc(2026, 3, 18, 11),
        ),
      );

      // Alert outside criteria date range
      await conflictDataSource.upsertAlert(
        WildlifeRiskAlert(
          id: 'alert-drift-out',
          parkId: 'PARK-MIN',
          source: AlertSource.collar,
          latitude: 8.01,
          longitude: 80.90,
          severity: AlertSeverity.low,
          createdAt: DateTime.utc(2026, 1, 10),
          status: AlertStatus.resolved,
          resolvedAt: DateTime.utc(2026, 1, 11),
        ),
      );

      final alertStore = DriftAlertReadStore(db);
      final reportStore = DriftReportReadStore(db, alerts: alertStore);

      final repo = ReportRepositoryImpl(
        store: reportStore,
        currentUser: () => DemoData.parkManager,
        now: () => DateTime.utc(2026, 4, 1, 12),
        newSnapshotId: () => 'snap-drift-001',
      );

      final criteria = testCriteria(
        parkId: 'PARK-MIN',
        start: reportStart,
        end: reportEnd,
      );

      // Generate report snapshot
      final report = await repo.generateReport(criteria);

      // Verify Snapshot integrity
      expect(report.snapshotId, 'snap-drift-001');
      expect(report.totalIncidents, 1);
      expect(report.completedPatrolCount, 1);
      expect(report.patrolCoverage, 88);
      expect(report.totalConflictAlerts, 2);
      expect(report.openAlertCount, 1); // alert-drift-1 is acknowledged (open)
      expect(report.resolvedAlertCount, 1); // alert-drift-2 is resolved
      expect(report.conflictTrends, isNotEmpty);

      // Test Export to CSV
      final csv = buildReportCsv(report);
      expect(csv, contains('snap-drift-001'));
      expect(csv, contains('incidents,total,1'));
      expect(csv, contains('patrol,completedPatrolCount,1'));
      expect(csv, contains('patrol,coveragePercent,88.0'));
      expect(csv, contains('conflict,total,2'));
      expect(csv, contains('conflict,open,1'));
      expect(csv, contains('conflict,resolved,1'));

      // Test Export via ReportExportServiceImpl
      final files = <String, List<int>>{};
      final exportService = ReportExportServiceImpl(
        save: (name, bytes) async {
          files[name] = bytes;
          return name;
        },
      );

      final csvPath = await exportService.exportCsv(report);
      final pdfPath = await exportService.exportPdf(report);

      expect(csvPath, contains('snap-drift-001'));
      expect(pdfPath, contains('snap-drift-001'));
      expect(files[csvPath], isNotEmpty);
      expect(files[pdfPath], isNotEmpty);

      final savedCsvContent = utf8.decode(files[csvPath]!);
      expect(savedCsvContent, csv);
    });
  });
}

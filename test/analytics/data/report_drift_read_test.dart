import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/analytics/data/drift_report_read_store.dart';
import 'package:wildlife_conservation_system/features/analytics/data/firestore_alert_read_store.dart';
import 'package:wildlife_conservation_system/features/analytics/data/report_repository_impl.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';

import '../../patrol/helpers.dart';
import '../helpers.dart';

void main() {
  test('drift reads are read-only and ignore pending incidents', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final observed = DateTime.utc(2026, 3, 12, 8);

    Future<void> insertIncident(String id, SyncState sync) {
      return db.into(db.incidentReportsTable).insert(
            IncidentReportsTableCompanion(
              id: Value(id),
              rangerId: const Value('R001'),
              parkId: const Value('PARK-MIN'),
              category: Value(IncidentCategory.poaching.wire),
              description: const Value('Snare on the trail'),
              observedAt: Value(observed),
              latitude: const Value(8.1),
              longitude: const Value(80.4),
              locationSource: Value(LocationSource.gps.wire),
              submissionStatus: Value(SubmissionStatus.submitted.wire),
              reviewStatus: Value(ReviewStatus.pendingReview.wire),
              syncState: Value(sync.wire),
              createdAt: Value(observed),
            ),
          );
    }

    await insertIncident('synced', SyncState.synchronized);
    await insertIncident('pending', SyncState.pending);
    await db.into(db.patrolsTable).insert(
          PatrolsTableCompanion(
            id: const Value('patrol-1'),
            routeId: const Value('RT-07'),
            rangerId: const Value('R001'),
            parkId: const Value('PARK-MIN'),
            scheduledFor: Value(DateTime.utc(2026, 3, 11)),
            status: Value(PatrolStatus.completed.wire),
            assignedAt: Value(DateTime.utc(2026, 3, 1)),
            completedAt: Value(DateTime.utc(2026, 3, 11, 16)),
            coveragePercent: const Value(75),
            syncState: Value(SyncState.synchronized.wire),
          ),
        );

    final beforeIncidents = await db.select(db.incidentReportsTable).get();
    final beforePatrols = await db.select(db.patrolsTable).get();

    final repo = ReportRepositoryImpl(
      store: DriftReportReadStore(db, alerts: const EmptyAlertReadStore()),
      currentUser: () => DemoData.parkManager,
      now: () => DateTime.utc(2026, 4, 1),
      newSnapshotId: () => 'snap-drift',
    );
    final report = await repo.generateReport(testCriteria());

    expect(report.totalIncidents, 1);
    expect(report.excludedPendingCount, 1);
    expect(report.completedPatrolCount, 1);
    expect(report.patrolCoverage, 75);
    expect(report.totalConflictAlerts, 0);

    final afterIncidents = await db.select(db.incidentReportsTable).get();
    final afterPatrols = await db.select(db.patrolsTable).get();
    expect(afterIncidents.map((row) => row.syncState),
        beforeIncidents.map((row) => row.syncState));
    expect(afterPatrols.single.coveragePercent,
        beforePatrols.single.coveragePercent);
    expect(afterPatrols.single.status, beforePatrols.single.status);
  });
}

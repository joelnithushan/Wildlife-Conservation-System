import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_aggregator.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_source_data.dart';
import 'package:wildlife_conservation_system/shared/models/report_criteria.dart';

import '../helpers.dart';

void main() {
  final generatedAt = DateTime.utc(2026, 4, 1, 9);

  ReportCriteria criteria({
    String parkId = 'PARK-MIN',
    DateTime? start,
    DateTime? end,
    List<IncidentCategory>? categories,
  }) =>
      testCriteria(
        parkId: parkId,
        start: start,
        end: end,
        categories: categories,
      );

  test('7-10. only synchronized incidents are counted, by category', () {
    final report = ReportAggregator.aggregate(
      criteria: criteria(
        categories: const [
          IncidentCategory.poaching,
          IncidentCategory.illegalLogging,
          IncidentCategory.other,
        ],
      ),
      parkName: 'Minneriya National Park',
      generatedAt: generatedAt,
      snapshotId: 'snap-1',
      source: ReportSourceData(
        incidents: [
          testIncident(id: 'a', category: IncidentCategory.poaching),
          testIncident(id: 'b', category: IncidentCategory.poaching),
          testIncident(id: 'c', category: IncidentCategory.illegalLogging),
          testIncident(
            id: 'pending',
            category: IncidentCategory.poaching,
            syncState: SyncState.pending,
          ),
          testIncident(
            id: 'failed',
            category: IncidentCategory.other,
            syncState: SyncState.failed,
          ),
        ],
      ),
    );

    expect(report.totalIncidents, 3);
    expect(report.incidentCounts[IncidentCategory.poaching], 2);
    expect(report.incidentCounts[IncidentCategory.illegalLogging], 1);
    expect(report.incidentCounts[IncidentCategory.other], 0);
    expect(report.excludedPendingCount, 2);
  });

  test('6/10. unselected categories are omitted from the totals', () {
    final report = ReportAggregator.aggregate(
      criteria: criteria(categories: const [IncidentCategory.poaching]),
      parkName: 'Minneriya',
      generatedAt: generatedAt,
      snapshotId: 'snap-cat',
      source: ReportSourceData(
        incidents: [
          testIncident(id: 'a', category: IncidentCategory.poaching),
          testIncident(id: 'b', category: IncidentCategory.animalInjury),
        ],
      ),
    );

    expect(report.totalIncidents, 1);
    expect(report.incidentCounts.containsKey(IncidentCategory.animalInjury),
        isFalse);
  });

  test('11. completed synchronized patrol coverage is averaged', () {
    final report = ReportAggregator.aggregate(
      criteria: criteria(),
      parkName: 'Minneriya',
      generatedAt: generatedAt,
      snapshotId: 'snap-cov',
      source: ReportSourceData(
        patrols: [
          testPatrol(
              id: 'c1',
              completedAt: DateTime.utc(2026, 3, 5),
              coveragePercent: 80),
          testPatrol(
              id: 'c2',
              completedAt: DateTime.utc(2026, 3, 12),
              coveragePercent: 40),
          testPatrol(
            id: 'active',
            status: PatrolStatus.inProgress,
            completedAt: null,
            coveragePercent: 100,
            scheduledFor: DateTime.utc(2026, 3, 6),
          ),
          testPatrol(
            id: 'pending',
            completedAt: DateTime.utc(2026, 3, 8),
            coveragePercent: 90,
            syncState: SyncState.pending,
          ),
        ],
        positions: [
          testPosition(
              id: 'pos-1', patrolId: 'c1', syncState: SyncState.pending),
        ],
      ),
    );

    expect(report.patrolCoverage, 60);
    expect(report.completedPatrolCount, 2);
    expect(report.hasPatrolCoverage, isTrue);
    expect(report.excludedPendingCount, 2);
  });

  test('11b. no completed patrols yields N/A coverage', () {
    final report = ReportAggregator.aggregate(
      criteria: criteria(),
      parkName: 'Minneriya',
      generatedAt: generatedAt,
      snapshotId: 'snap-na',
      source: const ReportSourceData(),
    );

    expect(report.hasPatrolCoverage, isFalse);
    expect(report.patrolCoverage, 0);
    expect(report.completedPatrolCount, 0);
  });

  test('12. conflict trends bucket alerts and split open versus resolved', () {
    final report = ReportAggregator.aggregate(
      criteria: criteria(),
      parkName: 'Minneriya',
      generatedAt: generatedAt,
      snapshotId: 'snap-trend',
      source: ReportSourceData(
        alerts: [
          testAlert(
              id: '1',
              createdAt: DateTime.utc(2026, 3, 3),
              status: AlertStatus.resolved),
          testAlert(
              id: '2',
              createdAt: DateTime.utc(2026, 3, 4),
              status: AlertStatus.newAlert),
          testAlert(
            id: '3',
            createdAt: DateTime.utc(2026, 3, 18),
            status: AlertStatus.responseInProgress,
          ),
        ],
      ),
    );

    expect(report.resolvedAlertCount, 1);
    expect(report.openAlertCount, 2);
    expect(report.totalConflictAlerts, 3);
    expect(
      report.conflictTrends.fold<int>(0, (sum, point) => sum + point.count),
      3,
    );
    expect(report.conflictTrends.where((point) => point.count > 0).length,
        greaterThan(1));
    expect(trendBucketFor(DateTime.utc(2026, 1, 1), DateTime.utc(2026, 6, 1)),
        TrendBucket.month);
  });

  test('13-14. selected park and period are enforced', () {
    final report = ReportAggregator.aggregate(
      criteria: criteria(),
      parkName: 'Minneriya',
      generatedAt: generatedAt,
      snapshotId: 'snap-scope',
      source: ReportSourceData(
        incidents: [
          testIncident(id: 'in'),
          testIncident(id: 'other-park', parkId: 'PARK-OTHER'),
          testIncident(id: 'before', observedAt: DateTime.utc(2026, 2, 1)),
          testIncident(id: 'after', observedAt: DateTime.utc(2026, 4, 2)),
        ],
        patrols: [
          testPatrol(
            id: 'other',
            parkId: 'PARK-OTHER',
            completedAt: DateTime.utc(2026, 3, 5),
            coveragePercent: 10,
          ),
        ],
        alerts: [
          testAlert(id: 'late', createdAt: DateTime.utc(2026, 5, 1)),
        ],
      ),
    );

    expect(report.totalIncidents, 1);
    expect(report.completedPatrolCount, 0);
    expect(report.totalConflictAlerts, 0);
  });

  test('15-17. empty input is a valid report with cutoff and pending count',
      () {
    final report = ReportAggregator.aggregate(
      criteria: criteria(),
      parkName: 'Minneriya National Park',
      generatedAt: generatedAt,
      snapshotId: 'snap-empty',
      source: ReportSourceData(
        incidents: [
          testIncident(id: 'pending', syncState: SyncState.pending),
        ],
      ),
    );

    expect(report.totalIncidents, 0);
    expect(report.totalConflictAlerts, 0);
    expect(report.hasPatrolCoverage, isFalse);
    expect(report.dataCutoff, generatedAt.toUtc());
    expect(report.generatedAt, generatedAt.toUtc());
    expect(report.excludedPendingCount, 1);
    expect(report.snapshotId, 'snap-empty');
    expect(report.criteria?.parkId, 'PARK-MIN');
  });

  test('18. a generated report stays immutable when inputs and filters change',
      () {
    final categories = [IncidentCategory.poaching];
    final selected = criteria(categories: categories);
    final incidents = [testIncident(id: 'a')];
    final report = ReportAggregator.aggregate(
      criteria: selected,
      parkName: 'Minneriya',
      generatedAt: generatedAt,
      snapshotId: 'snap-frozen',
      source: ReportSourceData(incidents: incidents),
    );
    final before = Map<IncidentCategory, int>.from(report.incidentCounts);

    categories.add(IncidentCategory.other);
    incidents.add(testIncident(id: 'b', category: IncidentCategory.other));
    expect(
      () => report.incidentCounts[IncidentCategory.other] = 9,
      throwsUnsupportedError,
    );

    final next = ReportAggregator.aggregate(
      criteria: criteria(),
      parkName: 'Minneriya',
      generatedAt: generatedAt,
      snapshotId: 'snap-next',
      source: ReportSourceData(incidents: incidents),
    );

    expect(report.incidentCounts, before);
    expect(report.totalIncidents, 1);
    expect(report.criteria?.categories, [IncidentCategory.poaching]);
    expect(next.snapshotId, isNot(report.snapshotId));
    expect(next.totalIncidents, greaterThan(report.totalIncidents));
  });
}

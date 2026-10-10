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
          IncidentCategory.snare,
          IncidentCategory.illegalCampsite,
          IncidentCategory.other,
        ],
      ),
      parkName: 'Minneriya National Park',
      generatedAt: generatedAt,
      snapshotId: 'snap-1',
      source: ReportSourceData(
        incidents: [
          testIncident(id: 'a', category: IncidentCategory.snare),
          testIncident(id: 'b', category: IncidentCategory.snare),
          testIncident(id: 'c', category: IncidentCategory.illegalCampsite),
          testIncident(
            id: 'pending',
            category: IncidentCategory.snare,
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
    expect(report.incidentCounts[IncidentCategory.snare], 2);
    expect(report.incidentCounts[IncidentCategory.illegalCampsite], 1);
    expect(report.incidentCounts[IncidentCategory.other], 0);
    expect(report.excludedPendingCount, 2);
  });

  test('6/10. unselected categories are omitted from the totals', () {
    final report = ReportAggregator.aggregate(
      criteria: criteria(categories: const [IncidentCategory.snare]),
      parkName: 'Minneriya',
      generatedAt: generatedAt,
      snapshotId: 'snap-cat',
      source: ReportSourceData(
        incidents: [
          testIncident(id: 'a', category: IncidentCategory.snare),
          testIncident(id: 'b', category: IncidentCategory.carcass),
        ],
      ),
    );

    expect(report.totalIncidents, 1);
    expect(report.incidentCounts.containsKey(IncidentCategory.carcass),
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
    // Only the pending patrol is an excluded field record. The pending position
    // on synchronized patrol 'c1' is telemetry within that patrol and must not
    // add to the count on its own.
    expect(report.excludedPendingCount, 1);
  });

  test('positions never inflate the excluded field-record count', () {
    final report = ReportAggregator.aggregate(
      criteria: criteria(),
      parkName: 'Minneriya',
      generatedAt: generatedAt,
      snapshotId: 'snap-positions',
      source: ReportSourceData(
        patrols: [
          testPatrol(
            id: 'p-pending',
            completedAt: DateTime.utc(2026, 3, 8),
            coveragePercent: 90,
            syncState: SyncState.pending,
          ),
        ],
        positions: [
          for (var i = 0; i < 50; i++)
            testPosition(
                id: 'pos-$i',
                patrolId: 'p-pending',
                syncState: SyncState.pending),
        ],
      ),
    );

    // One pending patrol with 50 pending positions is one excluded record.
    expect(report.excludedPendingCount, 1);
  });

  test('synchronized incidents with a bad location are still counted', () {
    final report = ReportAggregator.aggregate(
      criteria: criteria(categories: const [IncidentCategory.snare]),
      parkName: 'Minneriya',
      generatedAt: generatedAt,
      snapshotId: 'snap-badcoord',
      source: ReportSourceData(
        incidents: [
          testIncident(id: 'ok'),
          testIncident(id: 'no-lat', latitude: double.nan),
          testIncident(id: 'no-long', longitude: double.infinity),
        ],
      ),
    );

    // All three are synchronized in-park in-window poaching incidents; a
    // missing coordinate must not silently drop them from the count.
    expect(report.totalIncidents, 3);
    expect(report.incidentCounts[IncidentCategory.snare], 3);
    expect(report.excludedPendingCount, 0);
  });

  test('date window follows the local calendar day, not UTC digits', () {
    // Records at the very start and very end of the local calendar window must
    // be included regardless of the machine's UTC offset.
    final startOfWindow = DateTime(2026, 3, 1, 0, 0);
    final endOfWindow = DateTime(2026, 3, 31, 23, 59, 59);
    final report = ReportAggregator.aggregate(
      criteria: criteria(
        categories: const [IncidentCategory.snare],
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 31),
      ),
      parkName: 'Minneriya',
      generatedAt: DateTime.utc(2026, 4, 1, 9),
      snapshotId: 'snap-tz',
      source: ReportSourceData(
        incidents: [
          testIncident(id: 'first', observedAt: startOfWindow),
          testIncident(id: 'last', observedAt: endOfWindow),
          testIncident(
              id: 'before', observedAt: DateTime(2026, 2, 28, 23, 59, 59)),
        ],
      ),
    );

    expect(report.totalIncidents, 2);
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
    final categories = [IncidentCategory.snare];
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
    expect(report.criteria?.categories, [IncidentCategory.snare]);
    expect(next.snapshotId, isNot(report.snapshotId));
    expect(next.totalIncidents, greaterThan(report.totalIncidents));
  });
}

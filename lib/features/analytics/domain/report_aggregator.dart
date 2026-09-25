import '../../../core/enums/app_enums.dart';
import '../../../shared/models/conservation_report.dart';
import '../../../shared/models/report_criteria.dart';
import 'report_source_data.dart';

/// How conflict alerts are grouped on the trend chart.
///
/// Weekly when the selected period is 92 days or shorter; monthly otherwise.
enum TrendBucket { week, month }

TrendBucket trendBucketFor(DateTime start, DateTime end) {
  final startDay = DateTime.utc(start.year, start.month, start.day);
  final endDay = DateTime.utc(end.year, end.month, end.day);
  return endDay.difference(startDay).inDays > 92
      ? TrendBucket.month
      : TrendBucket.week;
}

/// Builds one immutable [ConservationReport] from a single [ReportSourceData].
///
/// Patrol coverage is the arithmetic mean of `coveragePercent` on patrols that
/// are completed, synchronized, in the selected park and period, and already
/// store a coverage percentage. Incomplete patrols are not included. When none
/// qualify, [ConservationReport.completedPatrolCount] is 0 and the UI shows N/A.
///
/// Only [SyncState.synchronized] incidents and patrols contribute to totals.
/// Pending and failed field records that match the filters are counted in
/// [ConservationReport.excludedPendingCount] and left out of the totals.
/// Wildlife risk alerts are online-first and have no sync state; every alert
/// in the park and period is included.
abstract final class ReportAggregator {
  static ConservationReport aggregate({
    required ReportCriteria criteria,
    required String parkName,
    required ReportSourceData source,
    required DateTime generatedAt,
    required String snapshotId,
  }) {
    final cutoff = generatedAt.toUtc();
    final windowStart = DateTime.utc(
      criteria.startDate.year,
      criteria.startDate.month,
      criteria.startDate.day,
    );
    final windowEnd = DateTime.utc(
      criteria.endDate.year,
      criteria.endDate.month,
      criteria.endDate.day,
      23,
      59,
      59,
      999,
    );
    final selected = _unique(criteria.categories);

    final counts = {for (final category in selected) category: 0};
    var excluded = 0;

    for (final incident in source.incidents) {
      if (incident.parkId != criteria.parkId) continue;
      if (!_inWindow(incident.observedAt, windowStart, windowEnd, cutoff)) {
        continue;
      }
      if (!selected.contains(incident.category)) continue;
      if (!incident.latitude.isFinite || !incident.longitude.isFinite) continue;
      if (incident.syncState == SyncState.synchronized) {
        counts[incident.category] = (counts[incident.category] ?? 0) + 1;
      } else {
        excluded++;
      }
    }

    final parkPatrols = [
      for (final patrol in source.patrols)
        if (patrol.parkId == criteria.parkId) patrol,
    ];
    final patrolById = {for (final patrol in parkPatrols) patrol.id: patrol};

    final coverageValues = <double>[];
    for (final patrol in parkPatrols) {
      final eventTime =
          patrol.completedAt ?? patrol.startedAt ?? patrol.scheduledFor;
      if (!_inWindow(eventTime, windowStart, windowEnd, cutoff)) continue;
      final countsForCoverage = patrol.status == PatrolStatus.completed &&
          patrol.syncState == SyncState.synchronized &&
          patrol.completedAt != null &&
          _usablePercent(patrol.coveragePercent);
      if (countsForCoverage) {
        coverageValues.add(patrol.coveragePercent!);
      } else if (patrol.syncState != SyncState.synchronized) {
        excluded++;
      }
    }

    for (final position in source.positions) {
      final patrol = patrolById[position.patrolId];
      if (patrol == null) continue;
      if (!_inWindow(position.timestamp, windowStart, windowEnd, cutoff)) {
        continue;
      }
      if (position.syncState != SyncState.synchronized) excluded++;
    }

    var open = 0;
    var resolved = 0;
    final alertMoments = <DateTime>[];
    for (final alert in source.alerts) {
      if (alert.parkId != criteria.parkId) continue;
      if (!_inWindow(alert.createdAt, windowStart, windowEnd, cutoff)) continue;
      alertMoments.add(alert.createdAt.toUtc());
      if (alert.status == AlertStatus.resolved) {
        resolved++;
      } else {
        open++;
      }
    }

    final trends = _trends(
      moments: alertMoments,
      windowStart: windowStart,
      windowEnd: windowEnd,
      bucket: trendBucketFor(criteria.startDate, criteria.endDate),
    );

    final coverage = coverageValues.isEmpty
        ? 0.0
        : coverageValues.reduce((a, b) => a + b) / coverageValues.length;

    return ConservationReport(
      snapshotId: snapshotId,
      criteria: ReportCriteria(
        parkId: criteria.parkId,
        startDate: criteria.startDate,
        endDate: criteria.endDate,
        categories: List<IncidentCategory>.unmodifiable(selected),
      ),
      parkName: parkName,
      incidentCounts: Map<IncidentCategory, int>.unmodifiable(counts),
      patrolCoverage: coverage,
      completedPatrolCount: coverageValues.length,
      conflictTrends: List<ConflictTrendPoint>.unmodifiable(trends),
      openAlertCount: open,
      resolvedAlertCount: resolved,
      dataCutoff: cutoff,
      excludedPendingCount: excluded,
      generatedAt: cutoff,
    );
  }

  static List<IncidentCategory> _unique(List<IncidentCategory> categories) {
    final unique = <IncidentCategory>[];
    for (final category in categories) {
      if (!unique.contains(category)) unique.add(category);
    }
    return unique;
  }

  static bool _inWindow(
    DateTime value,
    DateTime windowStart,
    DateTime windowEnd,
    DateTime cutoff,
  ) {
    final instant = value.toUtc();
    if (instant.isAfter(cutoff)) return false;
    return !instant.isBefore(windowStart) && !instant.isAfter(windowEnd);
  }

  static bool _usablePercent(double? value) => value != null && value.isFinite;

  static List<ConflictTrendPoint> _trends({
    required List<DateTime> moments,
    required DateTime windowStart,
    required DateTime windowEnd,
    required TrendBucket bucket,
  }) {
    final counts = <DateTime, int>{};
    for (final moment in moments) {
      final key = _align(moment, bucket);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final points = <ConflictTrendPoint>[];
    var cursor = _align(windowStart, bucket);
    final last = _align(windowEnd, bucket);
    var guard = 0;
    while (!cursor.isAfter(last) && guard < 520) {
      points.add(ConflictTrendPoint(
        periodStart: cursor,
        count: counts[cursor] ?? 0,
      ));
      cursor = bucket == TrendBucket.month
          ? DateTime.utc(cursor.year, cursor.month + 1, 1)
          : cursor.add(const Duration(days: 7));
      guard++;
    }
    return points;
  }

  static DateTime _align(DateTime value, TrendBucket bucket) {
    final day = DateTime.utc(
        value.toUtc().year, value.toUtc().month, value.toUtc().day);
    if (bucket == TrendBucket.month) {
      return DateTime.utc(day.year, day.month, 1);
    }
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
}

import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';
import '../../core/utils/serialization.dart';
import 'report_criteria.dart';

/// A single point in a conflict-trend series (e.g. alerts per day/week).
class ConflictTrendPoint extends Equatable {
  const ConflictTrendPoint({required this.periodStart, required this.count});

  final DateTime periodStart;
  final int count;

  Map<String, dynamic> toMap() =>
      {'periodStart': dateToWire(periodStart), 'count': count};

  factory ConflictTrendPoint.fromMap(Map<String, dynamic> map) =>
      ConflictTrendPoint(
        periodStart: dateFromWire(map['periodStart'])!,
        count: (map['count'] as num).toInt(),
      );

  @override
  List<Object?> get props => [periodStart, count];
}

/// Aggregated output of UC04. Computed from patrol, incident and response data —
/// there is no separate analytics store.
///
/// A report is one immutable snapshot. [patrolCoverage] is the average of
/// completed, synchronized [Patrol.coveragePercent] values in the window.
/// When [completedPatrolCount] is 0, coverage was not available (show N/A);
/// the stored percentage is then 0.
class ConservationReport extends Equatable {
  const ConservationReport({
    this.snapshotId = '',
    this.criteria,
    this.parkName = '',
    required this.incidentCounts,
    required this.patrolCoverage,
    required this.conflictTrends,
    required this.dataCutoff,
    required this.excludedPendingCount,
    required this.generatedAt,
    this.completedPatrolCount = 0,
    this.openAlertCount = 0,
    this.resolvedAlertCount = 0,
  });

  /// Stable id of this snapshot. Empty on reports built before UC04 snapshots.
  final String snapshotId;

  /// Filters that produced this snapshot. Export reads these; it does not re-query.
  final ReportCriteria? criteria;

  /// Display name of [ReportCriteria.parkId] at generation time.
  final String parkName;

  /// Incident totals keyed by category.
  final Map<IncidentCategory, int> incidentCounts;

  /// Average completed-patrol coverage (0–100). See [completedPatrolCount].
  final double patrolCoverage;

  /// How many completed, synchronized patrols were included in [patrolCoverage].
  final int completedPatrolCount;

  /// Conflict alert counts over time.
  final List<ConflictTrendPoint> conflictTrends;

  /// Alerts in the snapshot whose status is not resolved.
  final int openAlertCount;

  /// Alerts in the snapshot whose status is resolved.
  final int resolvedAlertCount;

  /// Instant the snapshot was taken. Records after this instant are excluded.
  final DateTime dataCutoff;

  /// How many pending or failed field records were excluded from the totals.
  final int excludedPendingCount;

  final DateTime generatedAt;

  int get totalIncidents =>
      incidentCounts.values.fold(0, (sum, count) => sum + count);

  int get totalConflictAlerts => openAlertCount + resolvedAlertCount;

  /// False when no completed patrol had a stored coverage percentage.
  bool get hasPatrolCoverage => completedPatrolCount > 0;

  Map<String, dynamic> toMap() => {
        'snapshotId': snapshotId,
        'criteria': criteria?.toMap(),
        'parkName': parkName,
        'incidentCounts':
            incidentCounts.map((key, value) => MapEntry(key.wire, value)),
        'patrolCoverage': patrolCoverage,
        'completedPatrolCount': completedPatrolCount,
        'conflictTrends': conflictTrends.map((p) => p.toMap()).toList(),
        'openAlertCount': openAlertCount,
        'resolvedAlertCount': resolvedAlertCount,
        'dataCutoff': dateToWire(dataCutoff),
        'excludedPendingCount': excludedPendingCount,
        'generatedAt': dateToWire(generatedAt),
      };

  factory ConservationReport.fromMap(Map<String, dynamic> map) =>
      ConservationReport(
        snapshotId: map['snapshotId'] as String? ?? '',
        criteria: map['criteria'] is Map
            ? ReportCriteria.fromMap(
                Map<String, dynamic>.from(map['criteria'] as Map),
              )
            : null,
        parkName: map['parkName'] as String? ?? '',
        incidentCounts: <IncidentCategory, int>{
          for (final entry in (map['incidentCounts'] as Map? ?? {}).entries)
            if (parseEnumOrNull(IncidentCategory.values, entry.key)
                case final category?)
              category: (entry.value as num).toInt(),
        },
        patrolCoverage: (map['patrolCoverage'] as num?)?.toDouble() ?? 0,
        completedPatrolCount:
            (map['completedPatrolCount'] as num?)?.toInt() ?? 0,
        conflictTrends: (map['conflictTrends'] as List?)
                ?.whereType<Map>()
                .map((m) =>
                    ConflictTrendPoint.fromMap(Map<String, dynamic>.from(m)))
                .toList() ??
            const [],
        openAlertCount: (map['openAlertCount'] as num?)?.toInt() ?? 0,
        resolvedAlertCount: (map['resolvedAlertCount'] as num?)?.toInt() ?? 0,
        dataCutoff: dateFromWire(map['dataCutoff'])!,
        excludedPendingCount:
            (map['excludedPendingCount'] as num?)?.toInt() ?? 0,
        generatedAt: dateFromWire(map['generatedAt'])!,
      );

  @override
  List<Object?> get props => [
        snapshotId,
        criteria,
        parkName,
        incidentCounts,
        patrolCoverage,
        completedPatrolCount,
        conflictTrends,
        openAlertCount,
        resolvedAlertCount,
        dataCutoff,
        excludedPendingCount,
        generatedAt,
      ];
}

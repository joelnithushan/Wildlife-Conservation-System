import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';
import '../../core/utils/serialization.dart';

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
class ConservationReport extends Equatable {
  const ConservationReport({
    required this.incidentCounts,
    required this.patrolCoverage,
    required this.conflictTrends,
    required this.dataCutoff,
    required this.excludedPendingCount,
    required this.generatedAt,
  });

  /// Incident totals keyed by category.
  final Map<IncidentCategory, int> incidentCounts;

  /// Overall patrol coverage percentage (0–100) across the criteria window.
  final double patrolCoverage;

  /// Conflict alert counts over time.
  final List<ConflictTrendPoint> conflictTrends;

  /// Records after this instant were excluded (still pending sync).
  final DateTime dataCutoff;

  /// How many pending records were excluded from the calculation.
  final int excludedPendingCount;

  final DateTime generatedAt;

  int get totalIncidents =>
      incidentCounts.values.fold(0, (sum, count) => sum + count);

  Map<String, dynamic> toMap() => {
        'incidentCounts':
            incidentCounts.map((key, value) => MapEntry(key.wire, value)),
        'patrolCoverage': patrolCoverage,
        'conflictTrends': conflictTrends.map((p) => p.toMap()).toList(),
        'dataCutoff': dateToWire(dataCutoff),
        'excludedPendingCount': excludedPendingCount,
        'generatedAt': dateToWire(generatedAt),
      };

  factory ConservationReport.fromMap(Map<String, dynamic> map) =>
      ConservationReport(
        incidentCounts: <IncidentCategory, int>{
          for (final entry in (map['incidentCounts'] as Map? ?? {}).entries)
            if (parseEnumOrNull(IncidentCategory.values, entry.key)
                case final category?)
              category: (entry.value as num).toInt(),
        },
        patrolCoverage: (map['patrolCoverage'] as num?)?.toDouble() ?? 0,
        conflictTrends: (map['conflictTrends'] as List?)
                ?.whereType<Map>()
                .map((m) =>
                    ConflictTrendPoint.fromMap(Map<String, dynamic>.from(m)))
                .toList() ??
            const [],
        dataCutoff: dateFromWire(map['dataCutoff'])!,
        excludedPendingCount: (map['excludedPendingCount'] as num?)?.toInt() ?? 0,
        generatedAt: dateFromWire(map['generatedAt'])!,
      );

  @override
  List<Object?> get props => [
        incidentCounts,
        patrolCoverage,
        conflictTrends,
        dataCutoff,
        excludedPendingCount,
        generatedAt,
      ];
}

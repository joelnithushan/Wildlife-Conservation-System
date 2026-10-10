import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/shared/models/conservation_report.dart';
import 'package:wildlife_conservation_system/shared/models/report_criteria.dart';

void main() {
  group('ReportCriteria', () {
    test('valid when start <= end', () {
      final criteria = ReportCriteria(
        parkId: 'PARK-MIN',
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 3, 1),
        categories: const [IncidentCategory.snare],
      );
      expect(criteria.isValid, isTrue);
      expect(ReportCriteria.fromMap(criteria.toMap()), criteria);
    });

    test('invalid when start after end', () {
      final criteria = ReportCriteria(
        parkId: 'PARK-MIN',
        startDate: DateTime.utc(2026, 3, 1),
        endDate: DateTime.utc(2026, 1, 1),
      );
      expect(criteria.isValid, isFalse);
    });
  });

  group('ConservationReport', () {
    test('totals and round-trip serialization', () {
      final report = ConservationReport(
        incidentCounts: const {
          IncidentCategory.snare: 3,
          IncidentCategory.illegalCampsite: 2,
        },
        patrolCoverage: 76.5,
        conflictTrends: [
          ConflictTrendPoint(periodStart: DateTime.utc(2026, 1, 1), count: 4),
          ConflictTrendPoint(periodStart: DateTime.utc(2026, 1, 8), count: 6),
        ],
        dataCutoff: DateTime.utc(2026, 3, 1),
        excludedPendingCount: 5,
        generatedAt: DateTime.utc(2026, 3, 1, 12),
      );

      expect(report.totalIncidents, 5);
      expect(ConservationReport.fromMap(report.toMap()), report);
    });
  });
}

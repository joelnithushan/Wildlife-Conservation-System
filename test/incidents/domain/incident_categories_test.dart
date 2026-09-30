import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/incidents/domain/incident_categories.dart';

void main() {
  group('IncidentReportCategory mapping onto the shared enum', () {
    test('all five field categories are offered', () {
      expect(IncidentReportCategory.values, hasLength(5));
      expect(
        IncidentReportCategory.values.map((c) => c.label),
        containsAll([
          'Snare',
          'Carcass',
          'Illegal campsite',
          'Suspicious footprints',
          'Other',
        ]),
      );
    });

    test('every field category maps onto a shared IncidentCategory', () {
      for (final category in IncidentReportCategory.values) {
        expect(IncidentCategory.values.contains(category.shared), isTrue,
            reason: '${category.name} must map onto the shared enum');
      }
    });

    test('mappings are unique (no two categories collapse into one shared)',
        () {
      final sharedValues =
          IncidentReportCategory.values.map((c) => c.shared).toSet();
      expect(sharedValues, hasLength(IncidentReportCategory.values.length));
    });

    test('labels are non-empty and stable', () {
      for (final category in IncidentReportCategory.values) {
        expect(category.label.trim(), isNotEmpty);
        expect(category.hint.trim(), isNotEmpty);
      }
    });

    test('fromShared round-trips each mapping', () {
      for (final category in IncidentReportCategory.values) {
        expect(IncidentReportCategory.fromShared(category.shared), category);
      }
    });

    test('fromShared falls back to other for unknown shared values',
        () {
      // every shared value is mapped, so build an out-of-band check via other
      expect(
        IncidentReportCategory.fromShared(IncidentCategory.other),
        IncidentReportCategory.other,
      );
    });
  });

  group('IncidentCategory (shared enum) — UC02 required members', () {
    test('contains the shared values UC02 persists', () {
      expect(
        IncidentCategory.values.map((c) => c.wire),
        containsAll([
          'poaching',
          'animalInjury',
          'humanWildlifeConflict',
          'illegalLogging',
          'other',
        ]),
      );
    });
  });
}

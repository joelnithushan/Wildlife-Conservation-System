import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_filter_validator.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_messages.dart';

void main() {
  const validator = ReportFilterValidator();
  final authorized = {'PARK-MIN'};
  final start = DateTime.utc(2026, 3, 1);
  final end = DateTime.utc(2026, 3, 31);

  test('1. valid filters are accepted', () {
    final error = validator.validate(
      parkId: 'PARK-MIN',
      startDate: start,
      endDate: end,
      categories: const [IncidentCategory.poaching, IncidentCategory.other],
      authorizedParkIds: authorized,
    );
    expect(error, isNull);
  });

  test('2. missing park is rejected', () {
    final error = validator.validate(
      parkId: '  ',
      startDate: start,
      endDate: end,
      categories: IncidentCategory.values,
      authorizedParkIds: authorized,
    );
    expect(error, ReportMessages.missingPark);
  });

  test('3. unauthorized park is rejected', () {
    final error = validator.validate(
      parkId: 'PARK-OTHER',
      startDate: start,
      endDate: end,
      categories: IncidentCategory.values,
      authorizedParkIds: authorized,
    );
    expect(error, ReportMessages.unauthorizedPark);
  });

  test('4. start date after end date is rejected', () {
    final error = validator.validate(
      parkId: 'PARK-MIN',
      startDate: end,
      endDate: start,
      categories: IncidentCategory.values,
      authorizedParkIds: authorized,
    );
    expect(error, ReportMessages.invalidRange);
  });

  test('5. a valid date range is accepted, including a single day', () {
    final sameDay = validator.validate(
      parkId: 'PARK-MIN',
      startDate: start,
      endDate: start,
      categories: const [IncidentCategory.poaching],
      authorizedParkIds: authorized,
    );
    final spanning = validator.validate(
      parkId: 'PARK-MIN',
      startDate: start,
      endDate: end,
      categories: const [IncidentCategory.poaching],
      authorizedParkIds: authorized,
    );
    expect(sameDay, isNull);
    expect(spanning, isNull);
  });

  test(
      '6. category filtering requires at least one category and accepts a subset',
      () {
    final none = validator.validate(
      parkId: 'PARK-MIN',
      startDate: start,
      endDate: end,
      categories: const [],
      authorizedParkIds: authorized,
    );
    final subset = validator.validate(
      parkId: 'PARK-MIN',
      startDate: start,
      endDate: end,
      categories: const [IncidentCategory.illegalLogging],
      authorizedParkIds: authorized,
    );
    expect(none, ReportMessages.missingCategories);
    expect(subset, isNull);
  });
}

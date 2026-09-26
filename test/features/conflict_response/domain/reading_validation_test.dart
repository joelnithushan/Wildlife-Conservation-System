import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/reading_validation.dart';
import 'package:wildlife_conservation_system/shared/models/location_reading.dart';

void main() {
  final now = DateTime.utc(2026, 9, 26, 10, 0, 0);

  LocationReading r({
    String id = 'r1',
    String animal = 'EL-07',
    double lat = 8.03,
    double lon = 80.90,
    DateTime? observed,
    DateTime? received,
  }) =>
      LocationReading(
        id: id,
        animalId: animal,
        latitude: lat,
        longitude: lon,
        observedAt: observed ?? now,
        receivedAt: received ?? observed ?? now,
      );

  test('valid reading passes', () {
    expect(
      ReadingValidator.validate(r(), now: now, seenReadingIds: {}),
      ReadingRejection.none,
    );
  });

  test('empty id rejected', () {
    expect(
      ReadingValidator.validate(r(id: ''), now: now, seenReadingIds: {}),
      ReadingRejection.invalidId,
    );
  });

  test('duplicate id rejected', () {
    expect(
      ReadingValidator.validate(r(id: 'x'), now: now, seenReadingIds: {'x'}),
      ReadingRejection.duplicate,
    );
  });

  test('out-of-range coordinates rejected', () {
    expect(
      ReadingValidator.validate(r(lat: 95), now: now, seenReadingIds: {}),
      ReadingRejection.invalidCoordinates,
    );
    expect(
      ReadingValidator.validate(r(lon: 200), now: now, seenReadingIds: {}),
      ReadingRejection.invalidCoordinates,
    );
  });

  test('received before observed rejected', () {
    final bad = r(
      observed: now,
      received: now.subtract(const Duration(minutes: 5)),
    );
    expect(
      ReadingValidator.validate(bad, now: now, seenReadingIds: {}),
      ReadingRejection.invalidTimes,
    );
  });

  test('stale reading rejected', () {
    final bad = r(observed: now.subtract(const Duration(hours: 2)));
    expect(
      ReadingValidator.validate(bad, now: now, seenReadingIds: {}),
      ReadingRejection.stale,
    );
  });

  test('coordinate helper flags NaN/Infinity', () {
    expect(ReadingValidator.areCoordinatesValid(double.nan, 80), isFalse);
    expect(ReadingValidator.areCoordinatesValid(8, double.infinity), isFalse);
    expect(ReadingValidator.areCoordinatesValid(8, 80), isTrue);
  });
}

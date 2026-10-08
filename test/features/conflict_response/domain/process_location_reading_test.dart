import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/usecases/process_location_reading.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/reading_validation.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';
import 'package:wildlife_conservation_system/shared/models/location_reading.dart';

/// Pure use-case tests: no repository, no Firebase, deterministic clock.
void main() {
  final now = DateTime.utc(2026, 9, 26, 10, 0, 0);
  final zones = DemoData.riskZones;
  const usecase = ProcessLocationReading();

  LocationReading r({
    String id = 'r1',
    double lat = 8.030,
    double lon = 80.900,
    DateTime? observed,
  }) =>
      LocationReading(
        id: id,
        animalId: 'EL-07',
        latitude: lat,
        longitude: lon,
        observedAt: observed ?? now,
        receivedAt: observed ?? now,
      );

  test('creates an alert for a valid reading inside a zone', () {
    final result = usecase.call(
      reading: r(),
      activeZones: zones,
      existingAlerts: const [],
      now: now,
    );
    expect(result.outcome, ProcessOutcome.alertCreated);
    expect(result.alert, isNotNull);
    expect(result.zone!.id, 'RZ-01');
  });

  test('no alert when the point is outside every zone', () {
    final result = usecase.call(
      reading: r(lat: 8.200, lon: 81.200),
      activeZones: zones,
      existingAlerts: const [],
      now: now,
    );
    expect(result.outcome, ProcessOutcome.outsideZone);
    expect(result.alert, isNull);
  });

  test('updates the existing open alert instead of duplicating', () {
    final first = usecase.call(
      reading: r(id: 'r1'),
      activeZones: zones,
      existingAlerts: const [],
      now: now,
    );
    final second = usecase.call(
      reading: r(id: 'r2'),
      activeZones: zones,
      existingAlerts: [first.alert!],
      now: now,
    );
    expect(second.outcome, ProcessOutcome.alertUpdated);
    expect(second.alert!.id, first.alert!.id);
  });

  test('update-in-place refreshes the alert location to the latest point', () {
    // First reading creates the alert at (8.030, 80.900).
    final first = usecase.call(
      reading: r(id: 'r1'),
      activeZones: zones,
      existingAlerts: const [],
      now: now,
    );
    // A later reading for the same animal, a different point STILL inside
    // RZ-01 (lat 8.020–8.040, lon 80.890–80.910), must update the same alert.
    final second = usecase.call(
      reading: r(id: 'r2', lat: 8.035, lon: 80.905),
      activeZones: zones,
      existingAlerts: [first.alert!],
      now: now,
    );
    expect(second.outcome, ProcessOutcome.alertUpdated);
    expect(second.alert!.id, first.alert!.id); // no duplicate, same stable ID
    // The manager must see the latest coordinates, not the stale originals.
    expect(second.alert!.latitude, 8.035);
    expect(second.alert!.longitude, 80.905);
  });

  test('rejects a stale reading', () {
    final result = usecase.call(
      reading: r(observed: now.subtract(const Duration(hours: 3))),
      activeZones: zones,
      existingAlerts: const [],
      now: now,
    );
    expect(result.outcome, ProcessOutcome.rejected);
    expect(result.rejection, ReadingRejection.stale);
  });

  test('rejects a duplicate reading id', () {
    final result = usecase.call(
      reading: r(id: 'seen'),
      activeZones: zones,
      existingAlerts: const [],
      now: now,
      seenReadingIds: {'seen'},
    );
    expect(result.rejection, ReadingRejection.duplicate);
  });

  test('community point raises a source=communityReport alert', () {
    final result = usecase.fromCommunityPoint(
      parkId: 'PARK-MIN',
      latitude: 8.010,
      longitude: 80.870,
      activeZones: zones,
      existingAlerts: const [],
      now: now,
    );
    expect(result.outcome, ProcessOutcome.alertCreated);
    expect(result.alert!.animalId, isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/patrol/domain/usecases/calculate_coverage.dart';
import 'package:wildlife_conservation_system/shared/models/geo_coordinate.dart';
import 'package:wildlife_conservation_system/shared/models/patrol_position.dart';
import 'package:wildlife_conservation_system/shared/models/patrol_route.dart';

void main() {
  const coverage = CalculateCoverage(toleranceMeters: 150);

  PatrolPosition pos(double lat, double lng) => PatrolPosition(
        id: 'p_$lat$lng',
        patrolId: 'patrol',
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.utc(2026, 9, 23),
        captureMode: CaptureMode.gps,
      );

  const route = PatrolRoute(
    id: 'RT-07',
    parkId: 'PARK-MIN',
    name: 'North Ridge',
    description: '',
    distanceKm: 7.4,
    plannedPath: [
      GeoCoordinate(latitude: 8.030, longitude: 80.890),
      GeoCoordinate(latitude: 8.040, longitude: 80.895),
      GeoCoordinate(latitude: 8.050, longitude: 80.900),
      GeoCoordinate(latitude: 8.060, longitude: 80.905),
    ],
  );

  test('0% when no positions recorded', () {
    expect(coverage(route, const []), 0);
  });

  test('0% when route has no planned path', () {
    const noPath = PatrolRoute(
      id: 'x',
      parkId: 'p',
      name: 'x',
      description: '',
      distanceKm: 1,
    );
    expect(coverage(noPath, [pos(8.03, 80.89)]), 0);
  });

  test('100% when every planned point is visited', () {
    final positions = route.plannedPath
        .map((c) => pos(c.latitude, c.longitude))
        .toList();
    expect(coverage(route, positions), 100);
  });

  test('50% when half the planned points are visited', () {
    final positions = [
      pos(route.plannedPath[0].latitude, route.plannedPath[0].longitude),
      pos(route.plannedPath[1].latitude, route.plannedPath[1].longitude),
    ];
    expect(coverage(route, positions), 50);
  });

  test('result always within 0..100', () {
    final positions = List.generate(
        50, (_) => pos(route.plannedPath.first.latitude, route.plannedPath.first.longitude));
    final result = coverage(route, positions);
    expect(result, greaterThanOrEqualTo(0));
    expect(result, lessThanOrEqualTo(100));
  });

  test('far-away positions do not count as coverage', () {
    expect(coverage(route, [pos(0, 0)]), 0);
  });
}

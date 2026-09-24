import '../../../../core/utils/geo_math.dart';
import '../../../../shared/models/patrol_position.dart';
import '../../../../shared/models/patrol_route.dart';

/// Calculates patrol coverage as a percentage (0–100).
///
/// Model: each planned-path waypoint is "covered" if at least one recorded
/// position lies within [toleranceMeters] of it. Coverage is the fraction of
/// planned waypoints that were covered.
///
/// This is intentionally simple and deterministic (no heavy GIS): easy to
/// explain, and unit-testable. If the route has no planned path we cannot
/// measure coverage against a plan, so we return 0.
class CalculateCoverage {
  const CalculateCoverage({this.toleranceMeters = 150});

  /// A planned waypoint counts as visited if a position is within this radius.
  final double toleranceMeters;

  double call(PatrolRoute route, List<PatrolPosition> positions) {
    final planned = route.plannedPath;
    if (planned.isEmpty) return 0;
    if (positions.isEmpty) return 0;

    var covered = 0;
    for (final point in planned) {
      final isVisited = positions.any((pos) =>
          GeoMath.distanceMeters(
            point.latitude,
            point.longitude,
            pos.latitude,
            pos.longitude,
          ) <=
          toleranceMeters);
      if (isVisited) covered++;
    }

    final percent = covered / planned.length * 100.0;
    return percent.clamp(0.0, 100.0);
  }
}

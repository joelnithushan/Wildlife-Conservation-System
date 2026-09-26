import '../../../shared/models/geo_coordinate.dart';
import '../../../shared/models/risk_zone.dart';

/// Deterministic, UI-free risk-zone evaluation.
///
/// Uses a standard ray-casting point-in-polygon test against each zone's
/// [RiskZone.boundary]. Kept simple and explainable (no external GIS): a point
/// on the boundary edge may fall either way, which is acceptable for this
/// university project.
abstract final class RiskEvaluator {
  /// Returns the first zone whose polygon contains the point, or null if the
  /// point is outside every configured zone.
  static RiskZone? firstMatchingZone(
    double latitude,
    double longitude,
    List<RiskZone> zones,
  ) {
    for (final zone in zones) {
      if (isInsideZone(latitude, longitude, zone)) return zone;
    }
    return null;
  }

  static bool isInsideZone(double latitude, double longitude, RiskZone zone) {
    return _pointInPolygon(latitude, longitude, zone.boundary);
  }

  /// Ray-casting: counts how many times a ray from the point crosses polygon
  /// edges. Odd => inside. A polygon needs at least three vertices.
  static bool _pointInPolygon(
    double latitude,
    double longitude,
    List<GeoCoordinate> polygon,
  ) {
    final n = polygon.length;
    if (n < 3) return false;

    final testX = longitude;
    final testY = latitude;
    var inside = false;

    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersects = ((yi > testY) != (yj > testY)) &&
          (testX < (xj - xi) * (testY - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }
}

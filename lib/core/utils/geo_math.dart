import 'dart:math' as math;

/// Small geospatial helpers shared across features (patrol coverage, risk zones).
abstract final class GeoMath {
  static const earthRadiusMeters = 6371000.0;

  /// Great-circle distance between two points in metres (haversine).
  static double distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRad(double degrees) => degrees * math.pi / 180.0;
}

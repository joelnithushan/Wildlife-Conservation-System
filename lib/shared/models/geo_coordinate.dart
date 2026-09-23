import 'package:equatable/equatable.dart';

/// A simple latitude/longitude pair used for paths, boundaries and points.
class GeoCoordinate extends Equatable {
  const GeoCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, dynamic> toMap() => {'latitude': latitude, 'longitude': longitude};

  factory GeoCoordinate.fromMap(Map<String, dynamic> map) => GeoCoordinate(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
      );

  static List<Map<String, dynamic>> listToMap(List<GeoCoordinate> path) =>
      path.map((c) => c.toMap()).toList();

  static List<GeoCoordinate> listFromMap(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => GeoCoordinate.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  List<Object?> get props => [latitude, longitude];
}

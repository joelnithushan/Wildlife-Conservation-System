import 'package:equatable/equatable.dart';

import 'geo_coordinate.dart';

/// A predefined patrol route within a park.
class PatrolRoute extends Equatable {
  const PatrolRoute({
    required this.id,
    required this.parkId,
    required this.name,
    required this.description,
    required this.distanceKm,
    this.plannedPath = const [],
  });

  final String id;
  final String parkId;
  final String name;
  final String description;
  final double distanceKm;
  final List<GeoCoordinate> plannedPath;

  Map<String, dynamic> toMap() => {
        'id': id,
        'parkId': parkId,
        'name': name,
        'description': description,
        'distanceKm': distanceKm,
        'plannedPath': GeoCoordinate.listToMap(plannedPath),
      };

  factory PatrolRoute.fromMap(Map<String, dynamic> map) => PatrolRoute(
        id: map['id'] as String,
        parkId: map['parkId'] as String,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
        plannedPath: GeoCoordinate.listFromMap(map['plannedPath']),
      );

  @override
  List<Object?> get props => [id, parkId, name, distanceKm];
}

import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';
import 'geo_coordinate.dart';

/// A geographic zone with an associated conflict/risk level.
class RiskZone extends Equatable {
  const RiskZone({
    required this.id,
    required this.parkId,
    required this.name,
    required this.riskLevel,
    this.boundary = const [],
  });

  final String id;
  final String parkId;
  final String name;
  final RiskLevel riskLevel;
  final List<GeoCoordinate> boundary;

  Map<String, dynamic> toMap() => {
        'id': id,
        'parkId': parkId,
        'name': name,
        'riskLevel': riskLevel.wire,
        'boundary': GeoCoordinate.listToMap(boundary),
      };

  factory RiskZone.fromMap(Map<String, dynamic> map) => RiskZone(
        id: map['id'] as String,
        parkId: map['parkId'] as String,
        name: map['name'] as String,
        riskLevel:
            parseEnum(RiskLevel.values, map['riskLevel'], fallback: RiskLevel.low),
        boundary: GeoCoordinate.listFromMap(map['boundary']),
      );

  @override
  List<Object?> get props => [id, parkId, name, riskLevel];
}

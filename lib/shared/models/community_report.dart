import 'package:equatable/equatable.dart';

import '../../core/utils/id_generator.dart';
import '../../core/utils/serialization.dart';

/// A wildlife sighting/conflict report submitted by a community member.
class CommunityReport extends Equatable {
  const CommunityReport({
    required this.id,
    required this.parkId,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.verified = false,
    this.verifiedBy,
  });

  factory CommunityReport.create({
    required String parkId,
    required String description,
    required double latitude,
    required double longitude,
    required DateTime createdAt,
  }) =>
      CommunityReport(
        id: IdGenerator.newId('community'),
        parkId: parkId,
        description: description,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
      );

  final String id;
  final String parkId;
  final String description;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final bool verified;
  final String? verifiedBy;

  CommunityReport copyWith({bool? verified, String? verifiedBy}) =>
      CommunityReport(
        id: id,
        parkId: parkId,
        description: description,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
        verified: verified ?? this.verified,
        verifiedBy: verifiedBy ?? this.verifiedBy,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'parkId': parkId,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': dateToWire(createdAt),
        'verified': verified,
        'verifiedBy': verifiedBy,
      };

  factory CommunityReport.fromMap(Map<String, dynamic> map) => CommunityReport(
        id: map['id'] as String,
        parkId: map['parkId'] as String,
        description: map['description'] as String? ?? '',
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        createdAt: dateFromWire(map['createdAt'])!,
        verified: map['verified'] as bool? ?? false,
        verifiedBy: map['verifiedBy'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, parkId, description, latitude, longitude, verified];
}

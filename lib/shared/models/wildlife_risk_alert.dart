import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/serialization.dart';

/// A wildlife conflict risk alert raised from a collar reading or community report.
class WildlifeRiskAlert extends Equatable {
  const WildlifeRiskAlert({
    required this.id,
    required this.parkId,
    required this.source,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.createdAt,
    this.animalId,
    this.riskZoneId,
    this.status = AlertStatus.newAlert,
    this.resolvedAt,
  });

  factory WildlifeRiskAlert.create({
    required String parkId,
    required AlertSource source,
    required double latitude,
    required double longitude,
    required AlertSeverity severity,
    required DateTime createdAt,
    String? animalId,
    String? riskZoneId,
  }) =>
      WildlifeRiskAlert(
        id: IdGenerator.newId('alert'),
        parkId: parkId,
        source: source,
        latitude: latitude,
        longitude: longitude,
        severity: severity,
        createdAt: createdAt,
        animalId: animalId,
        riskZoneId: riskZoneId,
      );

  final String id;
  final String parkId;
  final String? animalId;
  final String? riskZoneId;
  final AlertSource source;
  final double latitude;
  final double longitude;
  final AlertSeverity severity;
  final AlertStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  WildlifeRiskAlert copyWith({
    AlertStatus? status,
    String? riskZoneId,
    DateTime? resolvedAt,
  }) =>
      WildlifeRiskAlert(
        id: id,
        parkId: parkId,
        source: source,
        latitude: latitude,
        longitude: longitude,
        severity: severity,
        createdAt: createdAt,
        animalId: animalId,
        riskZoneId: riskZoneId ?? this.riskZoneId,
        status: status ?? this.status,
        resolvedAt: resolvedAt ?? this.resolvedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'parkId': parkId,
        'animalId': animalId,
        'riskZoneId': riskZoneId,
        'source': source.wire,
        'latitude': latitude,
        'longitude': longitude,
        'severity': severity.wire,
        'status': status.wire,
        'createdAt': dateToWire(createdAt),
        'resolvedAt': dateToWire(resolvedAt),
      };

  factory WildlifeRiskAlert.fromMap(Map<String, dynamic> map) => WildlifeRiskAlert(
        id: map['id'] as String,
        parkId: map['parkId'] as String,
        animalId: map['animalId'] as String?,
        riskZoneId: map['riskZoneId'] as String?,
        source:
            parseEnum(AlertSource.values, map['source'], fallback: AlertSource.collar),
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        severity: parseEnum(AlertSeverity.values, map['severity'],
            fallback: AlertSeverity.low),
        status:
            parseEnum(AlertStatus.values, map['status'], fallback: AlertStatus.newAlert),
        createdAt: dateFromWire(map['createdAt'])!,
        resolvedAt: dateFromWire(map['resolvedAt']),
      );

  @override
  List<Object?> get props => [id, parkId, source, severity, status];
}

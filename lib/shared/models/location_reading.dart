import 'package:equatable/equatable.dart';

import '../../core/utils/id_generator.dart';
import '../../core/utils/serialization.dart';

/// A single collar location reading for a tracked animal.
class LocationReading extends Equatable {
  const LocationReading({
    required this.id,
    required this.animalId,
    required this.latitude,
    required this.longitude,
    required this.observedAt,
    required this.receivedAt,
  });

  factory LocationReading.create({
    required String animalId,
    required double latitude,
    required double longitude,
    required DateTime observedAt,
    required DateTime receivedAt,
  }) =>
      LocationReading(
        id: IdGenerator.newId('reading'),
        animalId: animalId,
        latitude: latitude,
        longitude: longitude,
        observedAt: observedAt,
        receivedAt: receivedAt,
      );

  final String id;
  final String animalId;
  final double latitude;
  final double longitude;
  final DateTime observedAt;
  final DateTime receivedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'animalId': animalId,
        'latitude': latitude,
        'longitude': longitude,
        'observedAt': dateToWire(observedAt),
        'receivedAt': dateToWire(receivedAt),
      };

  factory LocationReading.fromMap(Map<String, dynamic> map) => LocationReading(
        id: map['id'] as String,
        animalId: map['animalId'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        observedAt: dateFromWire(map['observedAt'])!,
        receivedAt: dateFromWire(map['receivedAt'])!,
      );

  @override
  List<Object?> get props =>
      [id, animalId, latitude, longitude, observedAt, receivedAt];
}

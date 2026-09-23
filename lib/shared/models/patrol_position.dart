import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/serialization.dart';

/// A single GPS or manually-recorded waypoint captured during a patrol.
class PatrolPosition extends Equatable {
  const PatrolPosition({
    required this.id,
    required this.patrolId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.captureMode = CaptureMode.gps,
    this.syncState = SyncState.pending,
  });

  /// Creates a new position with a stable client-generated ID.
  factory PatrolPosition.create({
    required String patrolId,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    CaptureMode captureMode = CaptureMode.gps,
  }) =>
      PatrolPosition(
        id: IdGenerator.newId('pos'),
        patrolId: patrolId,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        captureMode: captureMode,
      );

  final String id;
  final String patrolId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final CaptureMode captureMode;
  final SyncState syncState;

  PatrolPosition copyWith({SyncState? syncState}) => PatrolPosition(
        id: id,
        patrolId: patrolId,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        captureMode: captureMode,
        syncState: syncState ?? this.syncState,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'patrolId': patrolId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': dateToWire(timestamp),
        'captureMode': captureMode.wire,
        'syncState': syncState.wire,
      };

  factory PatrolPosition.fromMap(Map<String, dynamic> map) => PatrolPosition(
        id: map['id'] as String,
        patrolId: map['patrolId'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        timestamp: dateFromWire(map['timestamp'])!,
        captureMode: parseEnum(CaptureMode.values, map['captureMode'],
            fallback: CaptureMode.gps),
        syncState:
            parseEnum(SyncState.values, map['syncState'], fallback: SyncState.pending),
      );

  @override
  List<Object?> get props =>
      [id, patrolId, latitude, longitude, timestamp, captureMode, syncState];
}

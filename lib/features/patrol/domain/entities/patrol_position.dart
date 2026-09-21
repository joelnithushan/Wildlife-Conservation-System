import 'package:equatable/equatable.dart';

import '../../../../shared/models/enums.dart';

class PatrolPosition extends Equatable {
  const PatrolPosition({
    required this.id,
    required this.patrolId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.captureMode = CaptureMode.gps,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String patrolId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final CaptureMode captureMode;
  final SyncStatus syncStatus;

  @override
  List<Object?> get props => [id, patrolId, latitude, longitude, timestamp];
}

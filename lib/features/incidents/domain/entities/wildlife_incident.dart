import 'package:equatable/equatable.dart';

import '../../../../shared/models/enums.dart';

class WildlifeIncident extends Equatable {
  const WildlifeIncident({
    required this.id,
    required this.rangerId,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.patrolId,
    this.photoUrl,
    this.localPhotoPath,
    this.status = 'open',
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String rangerId;
  final String? patrolId;
  final IncidentCategory category;
  final String description;
  final double latitude;
  final double longitude;
  final String? photoUrl;
  final String? localPhotoPath;
  final String status;
  final SyncStatus syncStatus;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, rangerId, category, status, syncStatus];
}

import 'package:equatable/equatable.dart';

import '../../../../shared/models/enums.dart';

class WildlifeRiskAlert extends Equatable {
  const WildlifeRiskAlert({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.createdAt,
    this.animalId,
    this.riskZoneId,
    this.status = AlertStatus.newAlert,
    this.assignedResponderId,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String? animalId;
  final double latitude;
  final double longitude;
  final String? riskZoneId;
  final AlertSeverity severity;
  final AlertStatus status;
  final String? assignedResponderId;
  final SyncStatus syncStatus;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, severity, status, syncStatus];
}

import 'package:equatable/equatable.dart';

import '../../../../shared/models/enums.dart';

class Patrol extends Equatable {
  const Patrol({
    required this.id,
    required this.rangerId,
    required this.status,
    this.routeId,
    this.routeName,
    this.startTime,
    this.endTime,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String rangerId;
  final String? routeId;
  final String? routeName;
  final PatrolStatus status;
  final DateTime? startTime;
  final DateTime? endTime;
  final SyncStatus syncStatus;

  @override
  List<Object?> get props => [id, rangerId, routeId, status, syncStatus];
}

import 'package:equatable/equatable.dart';

import '../../../../shared/models/enums.dart';

class ConflictResponse extends Equatable {
  const ConflictResponse({
    required this.id,
    required this.alertId,
    required this.responderId,
    this.status = ResponseStatus.assigned,
    this.notes,
    this.acknowledgedAt,
    this.resolvedAt,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String alertId;
  final String responderId;
  final ResponseStatus status;
  final String? notes;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final SyncStatus syncStatus;

  @override
  List<Object?> get props => [id, alertId, responderId, status];
}

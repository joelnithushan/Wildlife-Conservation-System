import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/serialization.dart';

/// An immutable record of a transition in a wildlife risk alert's lifecycle.
class AlertStatusChange extends Equatable {
  const AlertStatusChange({
    required this.id,
    required this.alertId,
    required this.toStatus,
    required this.timestamp,
    this.fromStatus,
    this.changedBy,
    this.reason,
  });

  factory AlertStatusChange.create({
    required String alertId,
    required AlertStatus toStatus,
    AlertStatus? fromStatus,
    String? changedBy,
    String? reason,
    DateTime? timestamp,
  }) =>
      AlertStatusChange(
        id: IdGenerator.newId('st_chg'),
        alertId: alertId,
        fromStatus: fromStatus,
        toStatus: toStatus,
        changedBy: changedBy,
        reason: reason,
        timestamp: timestamp ?? DateTime.now(),
      );

  final String id;
  final String alertId;
  final AlertStatus? fromStatus;
  final AlertStatus toStatus;
  final String? changedBy;
  final String? reason;
  final DateTime timestamp;

  AlertStatusChange copyWith({
    String? id,
    String? alertId,
    AlertStatus? fromStatus,
    AlertStatus? toStatus,
    String? changedBy,
    String? reason,
    DateTime? timestamp,
  }) =>
      AlertStatusChange(
        id: id ?? this.id,
        alertId: alertId ?? this.alertId,
        fromStatus: fromStatus ?? this.fromStatus,
        toStatus: toStatus ?? this.toStatus,
        changedBy: changedBy ?? this.changedBy,
        reason: reason ?? this.reason,
        timestamp: timestamp ?? this.timestamp,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'alertId': alertId,
        'fromStatus': fromStatus?.wire,
        'toStatus': toStatus.wire,
        'changedBy': changedBy,
        'reason': reason,
        'timestamp': dateToWire(timestamp),
      };

  factory AlertStatusChange.fromMap(Map<String, dynamic> map) =>
      AlertStatusChange(
        id: map['id'] as String,
        alertId: map['alertId'] as String,
        fromStatus: parseEnumOrNull(AlertStatus.values, map['fromStatus']),
        toStatus: parseEnum(
          AlertStatus.values,
          map['toStatus'],
          fallback: AlertStatus.newAlert,
        ),
        changedBy: map['changedBy'] as String?,
        reason: map['reason'] as String?,
        timestamp: dateFromWire(map['timestamp']) ?? DateTime.now(),
      );

  @override
  List<Object?> get props =>
      [id, alertId, fromStatus, toStatus, changedBy, reason, timestamp];
}

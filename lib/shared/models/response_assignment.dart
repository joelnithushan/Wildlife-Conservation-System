import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/serialization.dart';

/// A responder assignment for a wildlife risk alert (UC03).
class ResponseAssignment extends Equatable {
  const ResponseAssignment({
    required this.id,
    required this.alertId,
    required this.responderId,
    required this.responderRole,
    required this.assignedBy,
    required this.assignedAt,
    this.deliveryState = DeliveryState.pending,
    this.deliveredAt,
    this.acknowledgedAt,
    this.startedAt,
    this.statusNote,
    this.outcome,
    this.completedAt,
  });

  factory ResponseAssignment.create({
    required String alertId,
    required String responderId,
    required ResponderRole responderRole,
    required String assignedBy,
    required DateTime assignedAt,
  }) =>
      ResponseAssignment(
        id: IdGenerator.newId('assignment'),
        alertId: alertId,
        responderId: responderId,
        responderRole: responderRole,
        assignedBy: assignedBy,
        assignedAt: assignedAt,
      );

  final String id;
  final String alertId;
  final String responderId;
  final ResponderRole responderRole;
  final String assignedBy;
  final DateTime assignedAt;
  final DeliveryState deliveryState;
  final DateTime? deliveredAt;
  final DateTime? acknowledgedAt;
  final DateTime? startedAt;
  final String? statusNote;
  final String? outcome;
  final DateTime? completedAt;

  ResponseAssignment copyWith({
    DeliveryState? deliveryState,
    DateTime? deliveredAt,
    DateTime? acknowledgedAt,
    DateTime? startedAt,
    String? statusNote,
    String? outcome,
    DateTime? completedAt,
  }) =>
      ResponseAssignment(
        id: id,
        alertId: alertId,
        responderId: responderId,
        responderRole: responderRole,
        assignedBy: assignedBy,
        assignedAt: assignedAt,
        deliveryState: deliveryState ?? this.deliveryState,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
        startedAt: startedAt ?? this.startedAt,
        statusNote: statusNote ?? this.statusNote,
        outcome: outcome ?? this.outcome,
        completedAt: completedAt ?? this.completedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'alertId': alertId,
        'responderId': responderId,
        'responderRole': responderRole.wire,
        'assignedBy': assignedBy,
        'assignedAt': dateToWire(assignedAt),
        'deliveryState': deliveryState.wire,
        'deliveredAt': dateToWire(deliveredAt),
        'acknowledgedAt': dateToWire(acknowledgedAt),
        'startedAt': dateToWire(startedAt),
        'statusNote': statusNote,
        'outcome': outcome,
        'completedAt': dateToWire(completedAt),
      };

  factory ResponseAssignment.fromMap(Map<String, dynamic> map) =>
      ResponseAssignment(
        id: map['id'] as String,
        alertId: map['alertId'] as String,
        responderId: map['responderId'] as String,
        responderRole: parseEnum(ResponderRole.values, map['responderRole'],
            fallback: ResponderRole.ranger),
        assignedBy: map['assignedBy'] as String,
        assignedAt: dateFromWire(map['assignedAt'])!,
        deliveryState: parseEnum(DeliveryState.values, map['deliveryState'],
            fallback: DeliveryState.pending),
        deliveredAt: dateFromWire(map['deliveredAt']),
        acknowledgedAt: dateFromWire(map['acknowledgedAt']),
        startedAt: dateFromWire(map['startedAt']),
        statusNote: map['statusNote'] as String?,
        outcome: map['outcome'] as String?,
        completedAt: dateFromWire(map['completedAt']),
      );

  @override
  List<Object?> get props =>
      [id, alertId, responderId, responderRole, deliveryState];
}

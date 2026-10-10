import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/serialization.dart';

/// A scheduled/active patrol assigned to a ranger.
class Patrol extends Equatable {
  const Patrol({
    required this.id,
    required this.routeId,
    required this.rangerId,
    required this.parkId,
    required this.scheduledFor,
    required this.assignedAt,
    this.status = PatrolStatus.assigned,
    this.startedAt,
    this.completedAt,
    this.coveragePercent,
    this.syncState = SyncState.pending,
    this.updatedAt,
  });

  /// Creates a new patrol with a stable client-generated ID.
  factory Patrol.create({
    required String routeId,
    required String rangerId,
    required String parkId,
    required DateTime scheduledFor,
    required DateTime assignedAt,
  }) =>
      Patrol(
        id: IdGenerator.newId('patrol'),
        routeId: routeId,
        rangerId: rangerId,
        parkId: parkId,
        scheduledFor: scheduledFor,
        assignedAt: assignedAt,
      );

  final String id;
  final String routeId;
  final String rangerId;
  final String parkId;
  final DateTime scheduledFor;
  final PatrolStatus status;
  final DateTime assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double? coveragePercent;
  final SyncState syncState;

  /// When the local row was last written (save or sync acknowledgement). Local
  /// only — not sent to Firestore. Used to show a "last synced" time in the UI.
  final DateTime? updatedAt;

  Patrol copyWith({
    PatrolStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    double? coveragePercent,
    SyncState? syncState,
  }) =>
      Patrol(
        id: id,
        routeId: routeId,
        rangerId: rangerId,
        parkId: parkId,
        scheduledFor: scheduledFor,
        assignedAt: assignedAt,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        coveragePercent: coveragePercent ?? this.coveragePercent,
        syncState: syncState ?? this.syncState,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'routeId': routeId,
        'rangerId': rangerId,
        'parkId': parkId,
        'scheduledFor': dateToWire(scheduledFor),
        'status': status.wire,
        'assignedAt': dateToWire(assignedAt),
        'startedAt': dateToWire(startedAt),
        'completedAt': dateToWire(completedAt),
        'coveragePercent': coveragePercent,
        'syncState': syncState.wire,
      };

  factory Patrol.fromMap(Map<String, dynamic> map) => Patrol(
        id: map['id'] as String,
        routeId: map['routeId'] as String,
        rangerId: map['rangerId'] as String,
        parkId: map['parkId'] as String,
        scheduledFor: dateFromWire(map['scheduledFor'])!,
        assignedAt: dateFromWire(map['assignedAt'])!,
        status:
            parseEnum(PatrolStatus.values, map['status'], fallback: PatrolStatus.assigned),
        startedAt: dateFromWire(map['startedAt']),
        completedAt: dateFromWire(map['completedAt']),
        coveragePercent: (map['coveragePercent'] as num?)?.toDouble(),
        syncState:
            parseEnum(SyncState.values, map['syncState'], fallback: SyncState.pending),
      );

  @override
  List<Object?> get props => [id, routeId, rangerId, parkId, status, syncState];
}

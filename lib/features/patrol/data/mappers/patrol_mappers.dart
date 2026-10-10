import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../shared/models/patrol.dart';
import '../../../../shared/models/patrol_position.dart';

/// Converts between shared domain models and Drift rows/companions.
/// Kept out of the models so serialization stays framework-agnostic.
extension PatrolRowMapper on PatrolsTableData {
  Patrol toDomain() => Patrol(
        id: id,
        routeId: routeId,
        rangerId: rangerId,
        parkId: parkId,
        scheduledFor: scheduledFor,
        assignedAt: assignedAt,
        status:
            parseEnum(PatrolStatus.values, status, fallback: PatrolStatus.assigned),
        startedAt: startedAt,
        completedAt: completedAt,
        coveragePercent: coveragePercent,
        syncState:
            parseEnum(SyncState.values, syncState, fallback: SyncState.pending),
        updatedAt: updatedAt,
      );
}

extension PatrolCompanionMapper on Patrol {
  PatrolsTableCompanion toCompanion({DateTime? updatedAt}) =>
      PatrolsTableCompanion(
        id: Value(id),
        routeId: Value(routeId),
        rangerId: Value(rangerId),
        parkId: Value(parkId),
        scheduledFor: Value(scheduledFor),
        status: Value(status.wire),
        assignedAt: Value(assignedAt),
        startedAt: Value(startedAt),
        completedAt: Value(completedAt),
        coveragePercent: Value(coveragePercent),
        syncState: Value(syncState.wire),
        updatedAt: updatedAt == null ? const Value.absent() : Value(updatedAt),
      );
}

extension PatrolPositionRowMapper on PatrolPositionsTableData {
  PatrolPosition toDomain() => PatrolPosition(
        id: id,
        patrolId: patrolId,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        captureMode:
            parseEnum(CaptureMode.values, captureMode, fallback: CaptureMode.gps),
        syncState:
            parseEnum(SyncState.values, syncState, fallback: SyncState.pending),
      );
}

extension PatrolPositionCompanionMapper on PatrolPosition {
  PatrolPositionsTableCompanion toCompanion({DateTime? updatedAt}) =>
      PatrolPositionsTableCompanion(
        id: Value(id),
        patrolId: Value(patrolId),
        latitude: Value(latitude),
        longitude: Value(longitude),
        timestamp: Value(timestamp),
        captureMode: Value(captureMode.wire),
        syncState: Value(syncState.wire),
        updatedAt: updatedAt == null ? const Value.absent() : Value(updatedAt),
      );
}

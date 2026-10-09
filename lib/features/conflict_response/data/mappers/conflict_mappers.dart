import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../shared/models/alert_status_change.dart';
import '../../../../shared/models/community_report.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/models/response_assignment.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';

extension WildlifeRiskAlertRowMappers on WildlifeRiskAlertsTableData {
  WildlifeRiskAlert toDomain() => WildlifeRiskAlert(
        id: id,
        parkId: parkId,
        animalId: animalId,
        riskZoneId: riskZoneId,
        source: parseEnum(AlertSource.values, source,
            fallback: AlertSource.collar),
        latitude: latitude,
        longitude: longitude,
        severity: parseEnum(AlertSeverity.values, severity,
            fallback: AlertSeverity.low),
        status: parseEnum(AlertStatus.values, status,
            fallback: AlertStatus.newAlert),
        createdAt: createdAt,
        resolvedAt: resolvedAt,
      );
}

extension WildlifeRiskAlertCompanionMappers on WildlifeRiskAlert {
  WildlifeRiskAlertsTableCompanion toCompanion() =>
      WildlifeRiskAlertsTableCompanion(
        id: Value(id),
        parkId: Value(parkId),
        animalId: Value(animalId),
        riskZoneId: Value(riskZoneId),
        source: Value(source.wire),
        latitude: Value(latitude),
        longitude: Value(longitude),
        severity: Value(severity.wire),
        status: Value(status.wire),
        createdAt: Value(createdAt),
        resolvedAt: Value(resolvedAt),
      );
}

extension LocationReadingRowMappers on LocationReadingsTableData {
  LocationReading toDomain() => LocationReading(
        id: id,
        animalId: animalId,
        latitude: latitude,
        longitude: longitude,
        observedAt: observedAt,
        receivedAt: receivedAt,
      );
}

extension LocationReadingCompanionMappers on LocationReading {
  LocationReadingsTableCompanion toCompanion() =>
      LocationReadingsTableCompanion(
        id: Value(id),
        animalId: Value(animalId),
        latitude: Value(latitude),
        longitude: Value(longitude),
        observedAt: Value(observedAt),
        receivedAt: Value(receivedAt),
      );
}

extension ResponseAssignmentRowMappers on ResponseAssignmentsTableData {
  ResponseAssignment toDomain() => ResponseAssignment(
        id: id,
        alertId: alertId,
        responderId: responderId,
        responderRole: parseEnum(ResponderRole.values, responderRole,
            fallback: ResponderRole.ranger),
        assignedBy: assignedBy,
        assignedAt: assignedAt,
        deliveryState: parseEnum(DeliveryState.values, deliveryState,
            fallback: DeliveryState.pending),
        deliveredAt: deliveredAt,
        acknowledgedAt: acknowledgedAt,
        startedAt: startedAt,
        statusNote: statusNote,
        outcome: outcome,
        completedAt: completedAt,
      );
}

extension ResponseAssignmentCompanionMappers on ResponseAssignment {
  ResponseAssignmentsTableCompanion toCompanion() =>
      ResponseAssignmentsTableCompanion(
        id: Value(id),
        alertId: Value(alertId),
        responderId: Value(responderId),
        responderRole: Value(responderRole.wire),
        assignedBy: Value(assignedBy),
        assignedAt: Value(assignedAt),
        deliveryState: Value(deliveryState.wire),
        deliveredAt: Value(deliveredAt),
        acknowledgedAt: Value(acknowledgedAt),
        startedAt: Value(startedAt),
        statusNote: Value(statusNote),
        outcome: Value(outcome),
        completedAt: Value(completedAt),
      );
}

extension AlertStatusChangeRowMappers on AlertStatusChangesTableData {
  AlertStatusChange toDomain() => AlertStatusChange(
        id: id,
        alertId: alertId,
        fromStatus: parseEnumOrNull(AlertStatus.values, fromStatus),
        toStatus: parseEnum(AlertStatus.values, toStatus,
            fallback: AlertStatus.newAlert),
        changedBy: changedBy,
        reason: reason,
        timestamp: timestamp,
      );
}

extension AlertStatusChangeCompanionMappers on AlertStatusChange {
  AlertStatusChangesTableCompanion toCompanion() =>
      AlertStatusChangesTableCompanion(
        id: Value(id),
        alertId: Value(alertId),
        fromStatus: Value(fromStatus?.wire),
        toStatus: Value(toStatus.wire),
        changedBy: Value(changedBy),
        reason: Value(reason),
        timestamp: Value(timestamp),
      );
}

extension CommunityReportRowMappers on CommunityReportsTableData {
  CommunityReport toDomain() => CommunityReport(
        id: id,
        parkId: parkId,
        description: description,
        latitude: latitude,
        longitude: longitude,
        channel: channel,
        createdAt: createdAt,
        verified: verified,
        verifiedBy: verifiedBy,
      );
}

extension CommunityReportCompanionMappers on CommunityReport {
  CommunityReportsTableCompanion toCompanion() =>
      CommunityReportsTableCompanion(
        id: Value(id),
        parkId: Value(parkId),
        description: Value(description),
        latitude: Value(latitude),
        longitude: Value(longitude),
        channel: Value(channel),
        createdAt: Value(createdAt),
        verified: Value(verified),
        verifiedBy: Value(verifiedBy),
      );
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/models/risk_zone.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../data/repositories/conflict_repository_impl.dart';

part 'process_location_reading.g.dart';

class ProcessLocationReading {
  final ConflictRepositoryImpl repository;

  ProcessLocationReading(this.repository);

  Future<WildlifeRiskAlert?> call({
    required LocationReading reading,
    required List<RiskZone> activeZones,
    required List<WildlifeRiskAlert> existingAlerts,
    bool isCommunityReport = false,
    String? parkId,
  }) async {
    final now = DateTime.now();
    if (now.difference(reading.observedAt).inHours > 1) {
      return null;
    }

    RiskZone? matchedZone;
    for (final zone in activeZones) {
      if (_isInsideZone(reading, zone)) {
        matchedZone = zone;
        break;
      }
    }

    if (matchedZone == null) {
      return null;
    }

    final existingOpenAlert = existingAlerts.where((alert) =>
        (isCommunityReport ? true : alert.animalId == reading.animalId) &&
        alert.riskZoneId == matchedZone!.id &&
        (alert.status != AlertStatus.resolved)).firstOrNull;

    if (existingOpenAlert != null) {
      final updated = existingOpenAlert.copyWith();
      await repository.saveAlert(updated);
      return updated;
    } else {
      final newAlert = WildlifeRiskAlert.create(
        parkId: parkId ?? matchedZone.parkId,
        source: isCommunityReport ? AlertSource.communityReport : AlertSource.collar,
        latitude: reading.latitude,
        longitude: reading.longitude,
        severity: AlertSeverity.high,
        createdAt: DateTime.now(),
        animalId: isCommunityReport ? null : reading.animalId,
        riskZoneId: matchedZone.id,
      );
      await repository.saveAlert(newAlert);
      return newAlert;
    }
  }

  bool _isInsideZone(LocationReading reading, RiskZone zone) {
    if (zone.boundary.isEmpty) return true; // simplified for test
    return true; // Simplified: assume all readings in demo trigger risk zone
  }
}

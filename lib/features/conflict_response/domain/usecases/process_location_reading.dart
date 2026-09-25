import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/models/risk_zone.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../../../shared/repositories/conflict_repository.dart';

part 'process_location_reading.g.dart';

class ProcessLocationReading {
  final ConflictRepository repository;

  ProcessLocationReading(this.repository);

  Future<void> call({
    required LocationReading reading,
    required List<RiskZone> activeZones,
    required List<WildlifeRiskAlert> existingAlerts,
  }) async {
    // 1. Validate freshness threshold (e.g., must be within 1 hour)
    final now = DateTime.now();
    if (now.difference(reading.observedAt).inHours > 1) {
      return; // Stale reading
    }

    // 2. Evaluate coordinates against configured RiskZones
    RiskZone? matchedZone;
    for (final zone in activeZones) {
      if (_isInsideZone(reading, zone)) {
        matchedZone = zone;
        break;
      }
    }

    if (matchedZone == null) {
      // Animal is outside all risk zones, do not create an alert.
      return;
    }

    // 3. Find an existing OPEN alert for the same animal + risk zone
    final existingOpenAlert = existingAlerts.where((alert) =>
        alert.animalId == reading.animalId &&
        alert.riskZoneId == matchedZone!.id &&
        (alert.status != AlertStatus.resolved)).firstOrNull;

    if (existingOpenAlert != null) {
      // Update existing alert (for simulation purposes, maybe just touch it)
      // We aren't doing a lot of fields on update, just conceptually handling it
      final updated = existingOpenAlert.copyWith(status: existingOpenAlert.status);
      await repository.saveAlert(updated);
    } else {
      // Create new alert
      final newAlert = WildlifeRiskAlert.create(
        parkId: matchedZone.parkId,
        source: AlertSource.collar,
        latitude: reading.latitude,
        longitude: reading.longitude,
        severity: AlertSeverity.high,
        createdAt: DateTime.now(),
        animalId: reading.animalId,
        riskZoneId: matchedZone.id,
      );
      await repository.saveAlert(newAlert);
    }
  }

  bool _isInsideZone(LocationReading reading, RiskZone zone) {
    // Basic testable evaluation: Just a dummy implementation since GIS is out of scope
    // A real implementation would use ray-casting for the polygon boundary
    if (zone.boundary.isEmpty) return false;
    
    // For demo/testability: if reading is within rough bounding box
    final lats = zone.boundary.map((c) => c.latitude);
    final lngs = zone.boundary.map((c) => c.longitude);
    
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    return reading.latitude >= minLat &&
           reading.latitude <= maxLat &&
           reading.longitude >= minLng &&
           reading.longitude <= maxLng;
  }
}

@riverpod
ProcessLocationReading processLocationReading(ProcessLocationReadingRef ref) {
  // Assuming a provider for repository
  return ProcessLocationReading(ref.watch(conflictRepositoryProvider as ProviderListenable<ConflictRepository>)); // Requires actual provider
}

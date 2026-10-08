import '../../../../core/enums/app_enums.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/models/risk_zone.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../alert_rules.dart';
import '../conflict_config.dart';
import '../reading_validation.dart';
import '../risk_evaluation.dart';

/// What happened when a reading/report was processed.
enum ProcessOutcome {
  /// Reading rejected during validation (see [ProcessResult.rejection]).
  rejected,

  /// Valid but the point is outside every configured risk zone — no alert.
  outsideZone,

  /// A brand-new alert should be created.
  alertCreated,

  /// An existing open alert for the same animal + zone should be updated
  /// instead of creating a duplicate.
  alertUpdated,
}

/// Immutable result of the pure processing step. The repository is responsible
/// for persisting [alert] when present; this class performs no I/O.
class ProcessResult {
  const ProcessResult({
    required this.outcome,
    this.alert,
    this.zone,
    this.rejection = ReadingRejection.none,
  });

  final ProcessOutcome outcome;
  final WildlifeRiskAlert? alert;
  final RiskZone? zone;
  final ReadingRejection rejection;

  bool get raisedAlert =>
      outcome == ProcessOutcome.alertCreated ||
      outcome == ProcessOutcome.alertUpdated;
}

/// Pure UC03 core: turn a validated location point into an alert decision.
///
/// Deterministic and side-effect free — every input is passed in, so the same
/// logic serves collar readings (Trigger A) and verified community reports
/// (Trigger B) and is fully unit-testable without Firebase or the repository.
class ProcessLocationReading {
  const ProcessLocationReading({this.config = ConflictConfig.defaults});

  final ConflictConfig config;

  /// Process a collar [reading]. [seenReadingIds] enables duplicate detection.
  ProcessResult call({
    required LocationReading reading,
    required List<RiskZone> activeZones,
    required List<WildlifeRiskAlert> existingAlerts,
    required DateTime now,
    Set<String> seenReadingIds = const {},
  }) {
    final rejection = ReadingValidator.validate(
      reading,
      now: now,
      seenReadingIds: seenReadingIds,
      config: config,
    );
    if (rejection != ReadingRejection.none) {
      return ProcessResult(
        outcome: ProcessOutcome.rejected,
        rejection: rejection,
      );
    }

    return _evaluatePoint(
      parkIdFallbackFromZone: true,
      parkId: null,
      animalId: reading.animalId,
      latitude: reading.latitude,
      longitude: reading.longitude,
      source: AlertSource.collar,
      activeZones: activeZones,
      existingAlerts: existingAlerts,
      now: now,
    );
  }

  /// Process a point coming from a *verified* community report (Trigger B). No
  /// animal is associated; validity of the report is the caller's concern.
  ProcessResult fromCommunityPoint({
    required String parkId,
    required double latitude,
    required double longitude,
    required List<RiskZone> activeZones,
    required List<WildlifeRiskAlert> existingAlerts,
    required DateTime now,
  }) {
    if (!ReadingValidator.areCoordinatesValid(latitude, longitude)) {
      return const ProcessResult(
        outcome: ProcessOutcome.rejected,
        rejection: ReadingRejection.invalidCoordinates,
      );
    }
    return _evaluatePoint(
      parkIdFallbackFromZone: false,
      parkId: parkId,
      animalId: null,
      latitude: latitude,
      longitude: longitude,
      source: AlertSource.communityReport,
      activeZones: activeZones,
      existingAlerts: existingAlerts,
      now: now,
    );
  }

  ProcessResult _evaluatePoint({
    required bool parkIdFallbackFromZone,
    required String? parkId,
    required String? animalId,
    required double latitude,
    required double longitude,
    required AlertSource source,
    required List<RiskZone> activeZones,
    required List<WildlifeRiskAlert> existingAlerts,
    required DateTime now,
  }) {
    final zone = RiskEvaluator.firstMatchingZone(
      latitude,
      longitude,
      activeZones,
    );
    if (zone == null) {
      return const ProcessResult(outcome: ProcessOutcome.outsideZone);
    }

    final existing = AlertRules.findOpenAlert(
      existingAlerts,
      animalId: animalId,
      riskZoneId: zone.id,
    );
    if (existing != null) {
      // Update-in-place: refresh location so the manager sees the latest point,
      // never a second open alert for the same animal + zone.
      final updated = existing.copyWith(
        riskZoneId: zone.id,
        latitude: latitude,
        longitude: longitude,
      );
      return ProcessResult(
        outcome: ProcessOutcome.alertUpdated,
        alert: updated,
        zone: zone,
      );
    }

    final created = WildlifeRiskAlert.create(
      parkId: parkIdFallbackFromZone ? zone.parkId : parkId!,
      source: source,
      latitude: latitude,
      longitude: longitude,
      severity: _severityFor(zone.riskLevel),
      createdAt: now,
      animalId: animalId,
      riskZoneId: zone.id,
    );
    return ProcessResult(
      outcome: ProcessOutcome.alertCreated,
      alert: created,
      zone: zone,
    );
  }

  AlertSeverity _severityFor(RiskLevel level) => switch (level) {
        RiskLevel.high => AlertSeverity.high,
        RiskLevel.medium => AlertSeverity.medium,
        RiskLevel.low => AlertSeverity.low,
      };
}

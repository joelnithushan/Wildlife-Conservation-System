import '../../../core/enums/app_enums.dart';
import '../../../shared/models/response_assignment.dart';
import '../../../shared/models/wildlife_risk_alert.dart';

/// Raised when a UC03 business rule is violated. Carries a human-readable
/// [message] the UI can surface without leaking stack traces.
class ConflictException implements Exception {
  const ConflictException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Central, UI-free lifecycle rules for a [WildlifeRiskAlert].
///
/// Wraps the [AlertStatusTransitions] state machine defined on the enum and
/// adds UC03-specific guards (e.g. resolution requires a recorded outcome).
abstract final class AlertRules {
  /// Guard a status transition, throwing [ConflictException] when illegal.
  static void assertTransition(AlertStatus from, AlertStatus to) {
    if (from == to) return;
    if (!from.canTransitionTo(to)) {
      throw ConflictException(
        'Illegal alert transition: ${from.name} → ${to.name}.',
      );
    }
  }

  static bool isOpen(WildlifeRiskAlert alert) =>
      alert.status != AlertStatus.resolved;

  /// An open alert matching this animal + zone already exists (duplicate rule:
  /// at most one open alert per animal + risk zone).
  static WildlifeRiskAlert? findOpenAlert(
    List<WildlifeRiskAlert> alerts, {
    required String? animalId,
    required String riskZoneId,
  }) {
    for (final alert in alerts) {
      if (!isOpen(alert)) continue;
      if (alert.riskZoneId == riskZoneId && alert.animalId == animalId) {
        return alert;
      }
    }
    return null;
  }

  /// Resolution is only valid when the alert is in progress and at least one
  /// assignment has recorded an outcome.
  static void assertResolvable(
    WildlifeRiskAlert alert,
    List<ResponseAssignment> assignments,
  ) {
    if (alert.status == AlertStatus.resolved) {
      throw const ConflictException('Alert is already resolved.');
    }
    if (alert.status != AlertStatus.responseInProgress) {
      throw ConflictException(
        'Cannot resolve from ${alert.status.name}; response must be in progress.',
      );
    }
    final hasOutcome = assignments.any(
      (a) => (a.outcome ?? '').trim().isNotEmpty,
    );
    if (!hasOutcome) {
      throw const ConflictException(
        'Cannot resolve: no responder outcome recorded yet.',
      );
    }
  }
}

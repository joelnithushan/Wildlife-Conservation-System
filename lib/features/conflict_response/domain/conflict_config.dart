/// Tunable, deterministic thresholds for UC03 – Coordinate Wildlife Conflict
/// Response. Centralised so domain logic and tests share one source of truth
/// and no magic numbers leak into the UI.
class ConflictConfig {
  const ConflictConfig({
    this.readingFreshness = const Duration(minutes: 30),
    this.acknowledgementTimeout = const Duration(minutes: 15),
  });

  /// A collar/community reading older than this (observed-to-now) is stale and
  /// must not raise an alert.
  final Duration readingFreshness;

  /// If a responder does not acknowledge within this window from assignment,
  /// the assignment becomes overdue and can be escalated/reassigned.
  final Duration acknowledgementTimeout;

  static const ConflictConfig defaults = ConflictConfig();
}

import '../../../shared/models/response_assignment.dart';
import 'conflict_config.dart';

/// Pure, testable acknowledgement-timeout logic for UC03.
///
/// An assignment is "overdue" when it has been neither acknowledged nor
/// resolved and the acknowledgement window has elapsed since it was assigned.
/// Escalation/reassignment decisions are driven by [isOverdue].
abstract final class AcknowledgementMonitor {
  static bool isOverdue(
    ResponseAssignment assignment, {
    required DateTime now,
    ConflictConfig config = ConflictConfig.defaults,
  }) {
    if (assignment.acknowledgedAt != null) return false;
    final elapsed = now.difference(assignment.assignedAt);
    return elapsed > config.acknowledgementTimeout;
  }

  /// Time left before this assignment becomes overdue. Zero/negative when the
  /// window has already elapsed.
  static Duration timeRemaining(
    ResponseAssignment assignment, {
    required DateTime now,
    ConflictConfig config = ConflictConfig.defaults,
  }) {
    final deadline = assignment.assignedAt.add(config.acknowledgementTimeout);
    return deadline.difference(now);
  }
}

import '../../../../core/enums/app_enums.dart';
import '../../domain/notification_service.dart';

/// Development/offline notification service.
///
/// Stands in for Firebase Messaging: it "delivers" instantly and records the
/// call so screens can demonstrate delivery state. Domain logic depends only on
/// [NotificationService], so swapping in a real FCM implementation later needs
/// no changes to the repository or UI.
class SimulatedNotificationService implements NotificationService {
  SimulatedNotificationService({this.alwaysFail = false});

  /// When true, every send reports [DeliveryState.failed] — used to exercise the
  /// notification-failure edge case in tests and demos.
  final bool alwaysFail;

  final List<String> sentTo = [];

  @override
  Future<NotificationResult> notifyAssignment({
    required String assignmentId,
    required String responderId,
    required String title,
    required String body,
  }) async {
    if (alwaysFail) {
      return const NotificationResult(
        DeliveryState.failed,
        detail: 'Simulated delivery failure.',
      );
    }
    sentTo.add(responderId);
    return NotificationResult(
      DeliveryState.delivered,
      detail: 'Delivered to $responderId',
    );
  }
}

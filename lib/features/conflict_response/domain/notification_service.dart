import '../../../core/enums/app_enums.dart';

/// Result of attempting to deliver a responder notification.
///
/// Delivery is deliberately distinct from responder acknowledgement: a
/// [DeliveryState.delivered] notification has reached the device, but the
/// responder may still not have acknowledged the assignment.
class NotificationResult {
  const NotificationResult(this.state, {this.detail});
  final DeliveryState state;
  final String? detail;

  bool get isDelivered => state == DeliveryState.delivered;
}

/// Abstraction over push/notification delivery so domain logic never depends on
/// Firebase Messaging directly. A real implementation can wrap FCM; tests and
/// offline runs use a simulated implementation.
abstract interface class NotificationService {
  Future<NotificationResult> notifyAssignment({
    required String assignmentId,
    required String responderId,
    required String title,
    required String body,
  });
}

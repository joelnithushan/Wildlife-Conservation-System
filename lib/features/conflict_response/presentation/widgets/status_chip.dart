import 'package:flutter/material.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/theme/app_theme.dart';

/// Human-readable labels and status colours for UC03, kept in one place so
/// chips, cards and screens stay consistent with the frozen design.
abstract final class ConflictLabels {
  static String alertStatus(AlertStatus s) => switch (s) {
        AlertStatus.newAlert => 'New',
        AlertStatus.assigned => 'Assigned',
        AlertStatus.acknowledged => 'Acknowledged',
        AlertStatus.responseInProgress => 'In Progress',
        AlertStatus.resolved => 'Resolved',
      };

  static Color alertColor(AlertStatus s) => switch (s) {
        AlertStatus.newAlert => AppColors.warning,
        AlertStatus.assigned => AppColors.warning,
        AlertStatus.acknowledged => AppColors.primaryLight,
        AlertStatus.responseInProgress => AppColors.primary,
        AlertStatus.resolved => AppColors.success,
      };

  static String source(AlertSource s) => switch (s) {
        AlertSource.collar => 'GPS Collar',
        AlertSource.communityReport => 'Community Report',
      };

  static IconData sourceIcon(AlertSource s) => switch (s) {
        AlertSource.collar => Icons.sensors,
        AlertSource.communityReport => Icons.groups,
      };

  static String severity(AlertSeverity s) => switch (s) {
        AlertSeverity.low => 'Low',
        AlertSeverity.medium => 'Medium',
        AlertSeverity.high => 'High',
        AlertSeverity.critical => 'Critical',
      };

  static Color severityColor(AlertSeverity s) => switch (s) {
        AlertSeverity.low => AppColors.success,
        AlertSeverity.medium => AppColors.warning,
        AlertSeverity.high => AppColors.error,
        AlertSeverity.critical => AppColors.error,
      };

  static String delivery(DeliveryState s) => switch (s) {
        DeliveryState.pending => 'Delivery pending',
        DeliveryState.delivered => 'Delivered',
        DeliveryState.failed => 'Delivery failed',
      };

  static Color deliveryColor(DeliveryState s) => switch (s) {
        DeliveryState.pending => AppColors.warning,
        DeliveryState.delivered => AppColors.success,
        DeliveryState.failed => AppColors.error,
      };

  static String responderRole(ResponderRole r) => switch (r) {
        ResponderRole.ranger => 'Ranger',
        ResponderRole.communityLiaisonOfficer => 'Community Liaison Officer',
      };
}

/// A small pill showing a label against a colour, used for status/severity.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience chip bound to an [AlertStatus].
class AlertStatusChip extends StatelessWidget {
  const AlertStatusChip(this.status, {super.key});
  final AlertStatus status;

  @override
  Widget build(BuildContext context) => StatusChip(
        label: ConflictLabels.alertStatus(status),
        color: ConflictLabels.alertColor(status),
      );
}

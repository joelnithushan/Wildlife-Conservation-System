import 'package:flutter/material.dart';

import '../../core/enums/app_enums.dart';
import '../../core/theme/app_theme.dart';

/// Semantic intent for a status chip, mapped to the frozen palette.
enum StatusTone { neutral, info, success, warning, danger }

/// A small reusable chip for showing statuses consistently across modules.
///
/// Per the design system, chips are "text + icon + colour": an optional leading
/// icon (or a filled dot) precedes the label.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    this.showDot = false,
  });

  final String label;
  final StatusTone tone;

  /// Optional leading icon (e.g. check, clock). Takes priority over [showDot].
  final IconData? icon;

  /// When true (and no [icon]), shows a small filled dot before the label.
  final bool showDot;

  /// Convenience for record sync state (amber pending, green synced, red failed).
  factory StatusChip.forSyncState(SyncState state, {Key? key}) {
    final (label, tone, icon) = switch (state) {
      SyncState.pending => ('Pending', StatusTone.warning, Icons.schedule),
      SyncState.synchronized =>
        ('Synchronized', StatusTone.success, Icons.check_circle_outline),
      SyncState.failed => ('Failed', StatusTone.danger, Icons.error_outline),
    };
    return StatusChip(key: key, label: label, tone: tone, icon: icon);
  }

  Color get _color => switch (tone) {
        StatusTone.neutral => AppColors.textSecondary,
        StatusTone.info => AppColors.primary,
        StatusTone.success => AppColors.success,
        StatusTone.warning => AppColors.warning,
        StatusTone.danger => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _color),
            const SizedBox(width: 4),
          ] else if (showDot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style:
                TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

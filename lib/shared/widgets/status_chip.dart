import 'package:flutter/material.dart';

import '../../core/enums/app_enums.dart';
import '../../core/theme/app_theme.dart';

/// Semantic intent for a status chip, mapped to the frozen palette.
enum StatusTone { neutral, info, success, warning, danger }

/// A small reusable chip for showing statuses consistently across modules.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  /// Convenience for record sync state (amber pending, green synced, red failed).
  factory StatusChip.forSyncState(SyncState state, {Key? key}) {
    final tone = switch (state) {
      SyncState.pending => StatusTone.warning,
      SyncState.synchronized => StatusTone.success,
      SyncState.failed => StatusTone.danger,
    };
    return StatusChip(key: key, label: state.name, tone: tone);
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
      child: Text(
        label,
        style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

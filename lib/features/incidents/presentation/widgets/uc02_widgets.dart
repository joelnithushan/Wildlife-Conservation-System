import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/status_chip.dart';

/// Chip for a report's review lifecycle, using the shared [StatusChip].
StatusChip reviewStatusChip(ReviewStatus status) => switch (status) {
      ReviewStatus.pendingReview =>
        const StatusChip(label: 'Pending review', tone: StatusTone.warning, icon: Icons.schedule),
      ReviewStatus.underReview =>
        const StatusChip(label: 'Under review', tone: StatusTone.info, icon: Icons.visibility_outlined),
      ReviewStatus.verified =>
        const StatusChip(label: 'Verified', tone: StatusTone.success, icon: Icons.check_circle_outline),
      ReviewStatus.rejected =>
        const StatusChip(label: 'Rejected', tone: StatusTone.danger, icon: Icons.block),
    };

/// Chip for submission status (amber pending, green synced, red failed).
StatusChip syncStatusChip(SyncState state) => StatusChip.forSyncState(state);

/// Small uppercase section label used across the wizard screens.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
      );
}

/// Shows the captured photo from in-memory bytes, or a fallback frame.
class EvidencePreview extends StatelessWidget {
  const EvidencePreview({super.key, this.bytes, this.onRetake});

  final Uint8List? bytes;

  /// When provided, shows a "Change photo" overlay action.
  final VoidCallback? onRetake;

  @override
  Widget build(BuildContext context) {
    if (bytes == null || bytes!.isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: const Icon(Icons.image_outlined, size: 48, color: Colors.grey),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes!,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 180,
              width: double.infinity,
              alignment: Alignment.center,
              color: AppColors.background,
              child: const Icon(Icons.broken_image_outlined,
                  size: 48, color: Colors.grey),
            ),
          ),
        ),
        if (onRetake != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: FilledButton.tonalIcon(
              onPressed: onRetake,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retake'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                foregroundColor: AppColors.primaryDark,
              ),
            ),
          ),
      ],
    );
  }
}

/// Amber offline banner ("Offline – report saved on this device").
class OfflineSavedBanner extends StatelessWidget {
  const OfflineSavedBanner({super.key, this.pendingCount});

  final int? pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pendingCount == null
                  ? 'Pending Synchronisation. Your incident will synchronize when connectivity returns.'
                  : 'Pending Synchronisation ($pendingCount). Your incident will synchronize when connectivity returns.',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large field-friendly primary action used by the wizard.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

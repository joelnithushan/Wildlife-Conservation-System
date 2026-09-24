import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Amber banner shown while the device is offline during a patrol.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      color: AppColors.warning,
      icon: Icons.cloud_off,
      title: 'Offline – positions saved on this device',
      subtitle: '$pendingCount record(s) pending sync',
    );
  }
}

/// Green banner shown while/after synchronizing.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.message, this.isSyncing = false});

  final String message;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      color: AppColors.success,
      icon: Icons.cloud_done,
      title: isSyncing ? 'Back online – synchronizing' : message,
      subtitle: isSyncing ? message : null,
      trailing: isSyncing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

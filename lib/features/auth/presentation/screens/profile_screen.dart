import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/session/current_user.dart';
import '../widgets/logout_confirmation.dart';

/// Read-only account / profile page accessible from every authenticated area.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static String _parkName(String parkId) =>
      parkId == DemoData.park.id ? DemoData.park.name : parkId;

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary,
              child: Text(
                _initials(user.name),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              user.role.displayLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email.isEmpty ? '—' : user.email,
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: user.role.displayLabel,
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.park_outlined,
                  label: 'Park',
                  value: _parkName(user.parkId),
                ),
                if (user.isResponder) ...[
                  const Divider(height: 1),
                  _InfoTile(
                    icon: Icons.check_circle_outline,
                    label: 'Availability',
                    value: user.isAvailable ? 'Available' : 'Unavailable',
                    valueColor:
                        user.isAvailable ? AppColors.success : AppColors.warning,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => confirmAndSignOut(context, ref),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Sign Out',
                  style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: valueColor ?? AppColors.textPrimary,
        ),
      ),
    );
  }
}

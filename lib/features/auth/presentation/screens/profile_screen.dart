import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/role_nav.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/session/current_user.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../widgets/logout_confirmation.dart';

/// Read-only account / profile page accessible from every authenticated area.
///
/// Staff cannot edit their own details — only the system admin can (AGENTS.md
/// §10/§13). This screen just displays the profile the admin recorded.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static String _parkName(String parkId) =>
      parkId == DemoData.park.id ? DemoData.park.name : parkId;

  static String _formatDate(DateTime? d) => d == null
      ? '—'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser user = ref.watch(currentUserProvider);
    final isAdmin = user.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const WildGuardNavBar(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: UserAvatar(user: user, radius: 48)),
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
          if (user.username.isNotEmpty) ...[
            const SizedBox(height: 2),
            Center(
              child: Text(
                '@${user.username}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
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
                if (user.username.isNotEmpty)
                  _InfoTile(
                    icon: Icons.alternate_email,
                    label: 'Username',
                    value: user.username,
                    divider: true,
                  ),
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email.isEmpty ? '—' : user.email,
                  divider: true,
                ),
                if (!isAdmin) ...[
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    label: 'Work mobile',
                    value: _orDash(user.mobileNumber),
                    divider: true,
                  ),
                  _InfoTile(
                    icon: Icons.smartphone_outlined,
                    label: 'Personal mobile',
                    value: _orDash(user.personalMobileNumber),
                    divider: true,
                  ),
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'NIC number',
                    value: _orDash(user.nic),
                    divider: true,
                  ),
                  _InfoTile(
                    icon: Icons.wc_outlined,
                    label: 'Gender',
                    value: user.gender?.displayLabel ?? '—',
                    divider: true,
                  ),
                  _InfoTile(
                    icon: Icons.cake_outlined,
                    label: 'Date of birth',
                    value: _formatDate(user.dateOfBirth) +
                        (user.age != null ? '   (Age ${user.age})' : ''),
                    divider: true,
                  ),
                  _InfoTile(
                    icon: Icons.park_outlined,
                    label: 'Park',
                    value: _parkName(user.parkId),
                    divider: user.isResponder,
                  ),
                  if (user.isResponder)
                    _InfoTile(
                      icon: Icons.check_circle_outline,
                      label: 'Availability',
                      value: user.isAvailable ? 'Available' : 'Unavailable',
                      valueColor: user.isAvailable
                          ? AppColors.success
                          : AppColors.warning,
                      divider: false,
                    ),
                ],
                if (isAdmin)
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Role',
                    value: user.role.displayLabel,
                    divider: false,
                  ),
              ],
            ),
          ),

          if (!isAdmin) ...[
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your details are managed by the system administrator.',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],

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

  static String _orDash(String v) => v.trim().isEmpty ? '—' : v;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.divider = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          subtitle: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
        if (divider) const Divider(height: 1),
      ],
    );
  }
}

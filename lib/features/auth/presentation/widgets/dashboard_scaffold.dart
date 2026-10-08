import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/role_nav.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../../../shared/models/app_user.dart';

/// Shared layout for the role dashboards: a branded header (greeting, name,
/// park) plus a responsive set of action cards. Keeps the four dashboards
/// consistent and avoids duplicating the profile access + header.
class DashboardScaffold extends ConsumerWidget {
  const DashboardScaffold({
    super.key,
    required this.user,
    required this.actions,
  });

  final AppUser user;
  final List<DashboardAction> actions;

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _parkName(String parkId) =>
      parkId == DemoData.park.id ? DemoData.park.name : parkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WildGuard'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const WildGuardNavBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Header(
              greeting: _greeting(),
              name: user.name,
              role: user.role.displayLabel,
              park: _parkName(user.parkId),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 640 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: columns == 2 ? 2.4 : 3.2,
                  children: [
                    for (final a in actions) _ActionCard(action: a),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A single dashboard action / navigation card.
class DashboardAction {
  const DashboardAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.name,
    required this.role,
    required this.park,
  });

  final String greeting;
  final String name;
  final String role;
  final String park;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(role, style: const TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.park_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(park, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final DashboardAction action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: action.color.withValues(alpha: 0.12),
                child: Icon(action.icon, color: action.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

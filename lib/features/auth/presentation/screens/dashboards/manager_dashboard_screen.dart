import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/session/current_user.dart';
import '../../widgets/dashboard_scaffold.dart';

/// Park Manager home. Entry point to UC01 (Assign Patrol) plus the UC02–UC04
/// modules (which route to their existing screens/placeholders).
class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return DashboardScaffold(
      user: user,
      actions: [
        DashboardAction(
          icon: Icons.add_location_alt_outlined,
          title: 'Patrol Operations',
          subtitle: 'Assign patrol routes to rangers (UC01)',
          onTap: () => context.push(AppRoutes.assignPatrol),
        ),
        DashboardAction(
          icon: Icons.report_gmailerrorred_outlined,
          title: 'Incident Review',
          subtitle: 'Review reported incidents (UC02)',
          color: AppColors.warning,
          onTap: () => context.push(AppRoutes.incidents),
        ),
        DashboardAction(
          icon: Icons.crisis_alert_outlined,
          title: 'Conflict Response',
          subtitle: 'Risk alerts & response coordination (UC03)',
          color: AppColors.error,
          onTap: () => context.push(AppRoutes.conflictResponse),
        ),
        DashboardAction(
          icon: Icons.insights_outlined,
          title: 'Conservation Reports',
          subtitle: 'Analytics & exports (UC04)',
          color: AppColors.secondary,
          onTap: () => context.push(AppRoutes.analytics),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/session/current_user.dart';
import '../../widgets/dashboard_scaffold.dart';

/// Ranger home. Entry point to the completed UC01 "My Patrols" screen plus the
/// UC02/UC03 modules the ranger participates in.
class RangerDashboardScreen extends ConsumerWidget {
  const RangerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return DashboardScaffold(
      user: user,
      actions: [
        DashboardAction(
          icon: Icons.route_outlined,
          title: 'My Patrols',
          subtitle: 'View and run your assigned patrols (UC01)',
          onTap: () => context.push(AppRoutes.patrol),
        ),
        DashboardAction(
          icon: Icons.report_gmailerrorred_outlined,
          title: 'Report Incident',
          subtitle: 'Log a wildlife incident (UC02)',
          color: AppColors.warning,
          onTap: () => context.push(AppRoutes.incidents),
        ),
        DashboardAction(
          icon: Icons.crisis_alert_outlined,
          title: 'Assigned Response',
          subtitle: 'Conflict responses assigned to you (UC03)',
          color: AppColors.error,
          onTap: () => context.push(AppRoutes.conflictResponse),
        ),
      ],
    );
  }
}

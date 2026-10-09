import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/session/current_user.dart';
import '../../widgets/dashboard_scaffold.dart';

/// Community Liaison Officer home. Prepares access to UC03 conflict responses
/// assigned to the officer (routes to the existing conflict-response screen).
class CloDashboardScreen extends ConsumerWidget {
  const CloDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return DashboardScaffold(
      user: user,
      actions: [
        DashboardAction(
          icon: Icons.crisis_alert_outlined,
          title: 'Assigned Conflict Responses',
          subtitle: 'Wildlife conflict responses for your community',
          color: AppColors.error,
          onTap: () => context.push(AppRoutes.conflictResponse),
        ),
        DashboardAction(
          icon: Icons.campaign_outlined,
          title: 'Report Conflict (Community / SMS)',
          subtitle: 'Submit a sighting or simulate an SMS conflict report',
          color: AppColors.primary,
          onTap: () => context.push(AppRoutes.reportConflict),
        ),
      ],
    );
  }
}

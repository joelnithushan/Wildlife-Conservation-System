import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/session/current_user.dart';
import '../../widgets/dashboard_scaffold.dart';

/// Conservation Researcher home. Prepares access to UC04 conservation reports
/// (routes to the existing analytics screen).
class ResearcherDashboardScreen extends ConsumerWidget {
  const ResearcherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return DashboardScaffold(
      user: user,
      actions: [
        DashboardAction(
          icon: Icons.insights_outlined,
          title: 'Conservation Reports',
          subtitle: 'Generate analytics and export reports (UC04)',
          color: AppColors.secondary,
          onTap: () => context.push(AppRoutes.analytics),
        ),
      ],
    );
  }
}

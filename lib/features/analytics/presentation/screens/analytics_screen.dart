import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/session/current_user.dart';
import '../../data/category_labels.dart';
import '../../domain/report_access_policy.dart';
import '../../domain/report_messages.dart';
import '../report_flow_controller.dart';
import '../widgets/report_export_view.dart';
import '../widgets/report_filters_view.dart';
import '../widgets/report_results_view.dart';

/// UC04-S01 – Generate a Park Conservation Report.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final flow = ref.watch(reportFlowControllerProvider);
    final allowed = ReportAccessPolicy.canGenerate(user.role);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Conservation Reports'),
        actions: [
          PopupMenuButton<UserRole>(
            tooltip: 'Switch demo role',
            icon: const Icon(Icons.people_alt_outlined),
            onSelected: (role) =>
                ref.read(currentUserProvider.notifier).switchRole(role),
            itemBuilder: (context) => [
              for (final role in UserRole.values)
                CheckedPopupMenuItem(
                  value: role,
                  checked: role == user.role,
                  child: Text(userRoleLabel(role)),
                ),
            ],
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: allowed ? _step(flow) : const _AccessDenied(),
        ),
      ),
    );
  }

  Widget _step(ReportFlowState flow) {
    return switch (flow.step) {
      ReportStep.filters => ReportFiltersView(state: flow),
      ReportStep.generating => const ReportGeneratingView(),
      ReportStep.results when flow.report != null =>
        ReportResultsView(report: flow.report!),
      ReportStep.export when flow.report != null =>
        ReportExportView(report: flow.report!),
      ReportStep.unavailable => ReportUnavailableView(state: flow),
      _ => ReportFiltersView(state: flow),
    };
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          ReportMessages.accessDenied,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      ),
    );
  }
}

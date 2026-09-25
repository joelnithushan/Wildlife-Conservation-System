import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/conservation_report.dart';
import '../../domain/report_messages.dart';
import '../report_flow_controller.dart';

class ReportExportView extends ConsumerWidget {
  const ReportExportView({super.key, required this.report});

  final ConservationReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportFlowControllerProvider);
    final notifier = ref.read(reportFlowControllerProvider.notifier);
    final busy = state.exportPhase == ReportExportPhase.exporting;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Export report', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text(ReportMessages.exportSameSnapshot),
        const SizedBox(height: 8),
        Text(
          'Snapshot ${report.snapshotId}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : notifier.exportPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('PDF'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: busy ? null : notifier.exportCsv,
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('CSV'),
        ),
        if (busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        if (state.exportError != null) ...[
          const SizedBox(height: 16),
          Text(state.exportError!,
              style: const TextStyle(color: AppColors.error)),
        ],
        if (state.exportPath != null) ...[
          const SizedBox(height: 16),
          Text('Saved: ${state.exportPath}'),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: busy ? null : notifier.closeExport,
          child: const Text('Back to report'),
        ),
      ],
    );
  }
}

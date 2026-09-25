import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_extensions.dart';
import '../../../../shared/models/conservation_report.dart';
import '../../data/category_labels.dart';
import '../../domain/report_messages.dart';
import '../report_flow_controller.dart';
import 'report_charts.dart';

class ReportResultsView extends ConsumerWidget {
  const ReportResultsView({super.key, required this.report});

  final ConservationReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(reportFlowControllerProvider.notifier);
    final criteria = report.criteria;
    final park =
        report.parkName.isEmpty ? criteria?.parkId ?? '—' : report.parkName;
    final period = criteria == null
        ? '—'
        : '${criteria.startDate.toDisplayDate()} – ${criteria.endDate.toDisplayDate()}';
    final empty = report.totalIncidents == 0 &&
        !report.hasPatrolCoverage &&
        report.totalConflictAlerts == 0;
    final coverage = report.hasPatrolCoverage
        ? '${report.patrolCoverage.toStringAsFixed(1)}%'
        : 'N/A';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(park, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(period, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text('Generated ${report.generatedAt.toDisplayDateTime()}'),
        Text('Data cutoff ${report.dataCutoff.toDisplayDateTime()}'),
        const SizedBox(height: 8),
        Text(
          ReportMessages.pendingExcluded(report.excludedPendingCount),
          style: const TextStyle(color: AppColors.secondaryDark),
        ),
        const SizedBox(height: 4),
        const Text(
          ReportMessages.synchronizedOnly,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        if (empty) ...[
          const SizedBox(height: 16),
          const Text(
            ReportMessages.empty,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final cards = [
              _SummaryCard(
                label: 'Total incidents',
                value: '${report.totalIncidents}',
                icon: Icons.warning_amber,
                color: AppColors.warning,
              ),
              _SummaryCard(
                label: leadingCategoryLabel(report),
                value: '${leadingCategoryCount(report)}',
                icon: Icons.category_outlined,
                color: AppColors.primary,
              ),
              _SummaryCard(
                label: 'Patrol coverage',
                value: coverage,
                icon: Icons.route,
                color: AppColors.primaryLight,
              ),
              _SummaryCard(
                label: 'Conflict alerts',
                value: '${report.totalConflictAlerts}',
                icon: Icons.crisis_alert,
                color: AppColors.error,
              ),
            ];
            if (!wide) {
              return Wrap(spacing: 12, runSpacing: 12, children: cards);
            }
            return Row(
              children: [
                for (final card in cards) ...[
                  Expanded(child: card),
                  if (card != cards.last) const SizedBox(width: 12),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          report.hasPatrolCoverage
              ? 'Patrol coverage is the average of ${report.completedPatrolCount} completed patrols.'
              : 'Patrol coverage is N/A because no completed patrol had a coverage value.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final charts = [
              _ChartCard(
                title: 'Incidents by category',
                child: IncidentCategoryChart(report: report),
              ),
              _ChartCard(
                title: 'Conflict alerts over time',
                child: ConflictTrendChart(report: report),
              ),
            ];
            if (constraints.maxWidth < 800) {
              return Column(
                children: [
                  charts[0],
                  const SizedBox(height: 12),
                  charts[1],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: charts[0]),
                const SizedBox(width: 12),
                Expanded(child: charts[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (criteria != null)
          ...criteria.categories.map(
            (category) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${incidentCategoryLabel(category)}: ${report.incidentCounts[category] ?? 0}',
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text('Open alerts: ${report.openAlertCount}'),
        Text('Resolved alerts: ${report.resolvedAlertCount}'),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: notifier.changeFilters,
                child: const Text('Change Filters'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: notifier.openExport,
                child: const Text('Export'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

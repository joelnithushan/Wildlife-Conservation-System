import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_extensions.dart';
import '../../../../shared/session/current_user.dart';
import '../../data/category_labels.dart';
import '../../domain/report_access_policy.dart';
import '../../domain/report_messages.dart';
import '../report_flow_controller.dart';

class ReportFiltersView extends ConsumerWidget {
  const ReportFiltersView({super.key, required this.state});

  final ReportFlowState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final parks = ReportAccessPolicy.permittedParks(user);
    final notifier = ref.read(reportFlowControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Choose a park, period, and incident categories.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'The report uses one snapshot of synchronized records. Pending field records are counted and left out of the totals.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          key: ValueKey(state.parkId),
          initialValue: state.parkId,
          decoration: const InputDecoration(labelText: 'Park'),
          items: [
            for (final park in parks)
              DropdownMenuItem(value: park.id, child: Text(park.name)),
          ],
          onChanged: notifier.setPark,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: 'Start date',
                value: state.startDate,
                onPick: (value) => notifier.setStartDate(value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateField(
                label: 'End date',
                value: state.endDate,
                onPick: (value) => notifier.setEndDate(value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Incident categories',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in IncidentCategory.values)
              FilterChip(
                label: Text(incidentCategoryLabel(category)),
                selected: state.categories.contains(category),
                onSelected: (_) => notifier.toggleCategory(category),
              ),
          ],
        ),
        if (state.validationError != null) ...[
          const SizedBox(height: 16),
          _InlineError(message: state.validationError!),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => notifier.generate(),
          child: const Text('Generate Report'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(2020),
          lastDate: DateTime(now.year + 2),
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value == null ? 'Required' : value!.toDisplayDate()),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

class ReportGeneratingView extends StatelessWidget {
  const ReportGeneratingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              ReportMessages.generating,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportUnavailableView extends ConsumerWidget {
  const ReportUnavailableView({super.key, required this.state});

  final ReportFlowState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(reportFlowControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InlineError(
          message: state.serviceError ?? ReportMessages.serviceUnavailable,
        ),
        const SizedBox(height: 16),
        Text(
          'Selected filters are unchanged.',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text('Park: ${state.parkId ?? '—'}'),
        Text(
          'Period: ${state.startDate?.toDisplayDate() ?? '—'} – ${state.endDate?.toDisplayDate() ?? '—'}',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: notifier.retry,
          child: const Text('Retry'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: notifier.changeFilters,
          child: const Text('Change Filters'),
        ),
      ],
    );
  }
}

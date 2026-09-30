import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/date_extensions.dart';
import '../../../../shared/models/incident_report.dart';
import '../../../../shared/session/current_user.dart';
import '../providers/incident_providers.dart';
import '../widgets/uc02_widgets.dart';

/// UC02-S02 – Screen 7: Incident Review queue (Park Manager).
///
/// Only synchronized reports appear here (business rule). Default filter is
/// Pending review; handles loading, empty, error and filter states.
class IncidentReviewQueueScreen extends ConsumerStatefulWidget {
  const IncidentReviewQueueScreen({super.key});

  @override
  ConsumerState<IncidentReviewQueueScreen> createState() =>
      _IncidentReviewQueueScreenState();
}

class _IncidentReviewQueueScreenState
    extends ConsumerState<IncidentReviewQueueScreen> {
  ReviewStatus _filter = ReviewStatus.pendingReview;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final queueAsync = ref.watch(incidentReviewQueueProvider(_filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Incident Review')),
      body: Column(
        children: [
          // Authorization guard: reviewers only.
          if (user.role != UserRole.parkManager)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(10),
              child: const Text(
                'Only authorized reviewers can act on these reports.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final status in ReviewStatus.values)
                    ChoiceChip(
                      label: Text(switch (status) {
                        ReviewStatus.pendingReview => 'Pending review',
                        ReviewStatus.underReview => 'Under review',
                        ReviewStatus.verified => 'Verified',
                        ReviewStatus.rejected => 'Rejected',
                      }),
                      selected: _filter == status,
                      onSelected: (_) =>
                          setState(() => _filter = status),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          Expanded(
            child: queueAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: 'The review service is unavailable.\n$e',
                onRetry: () =>
                    ref.invalidate(incidentReviewQueueProvider(_filter)),
              ),
              data: (reports) {
                if (reports.isEmpty) {
                  return _EmptyQueue(filter: _filter);
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(incidentReviewQueueProvider(_filter).future),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _QueueCard(
                          report: report,
                          onOpen: () => context
                              .push(AppRoutes.incidentReviewDetailFor(report.id)),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.report, required this.onOpen});

  final IncidentReport report;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onOpen,
        title: Text(
          report.category.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Observed ${report.observedAt.toDisplayDateTime()}\n'
          'Ranger: ${report.rangerId}',
          style: const TextStyle(height: 1.4),
        ),
        isThreeLine: true,
        trailing: reviewStatusChip(report.reviewStatus),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.filter});

  final ReviewStatus filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 8),
          Text(switch (filter) {
            ReviewStatus.pendingReview =>
              'No reports waiting for review.',
            ReviewStatus.underReview => 'No reports under review.',
            ReviewStatus.verified => 'No verified reports yet.',
            ReviewStatus.rejected => 'No rejected reports.',
          }),
          const SizedBox(height: 4),
          Text(
            'Reports appear here once rangers\' devices synchronize.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 56, color: Colors.red),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

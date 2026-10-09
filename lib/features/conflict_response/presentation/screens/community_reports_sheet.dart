import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/session/current_user.dart';
import '../providers/conflict_providers.dart';
import '../widgets/status_chip.dart';

/// Trigger B — Park Manager reviews community reports and verifies credible ones.
/// Verifying a credible report feeds the same alert-response workflow.
class CommunityReportsSheet extends ConsumerWidget {
  const CommunityReportsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkId = ref.watch(currentUserProvider).parkId;
    final reportsAsync = ref.watch(communityReportsProvider(parkId));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Community Reports',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.reportConflict);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Report'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Verify credible reports to raise or update an alert.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: reportsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (reports) {
                    if (reports.isEmpty) {
                      return const Center(child: Text('No community reports.'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: reports.length,
                      itemBuilder: (context, i) {
                        final r = reports[i];
                        final date = DateFormat('MMM d, HH:mm')
                            .format(r.createdAt.toLocal());
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(r.description)),
                                    const SizedBox(width: 8),
                                    StatusChip(
                                      label: r.channel,
                                      color: r.channel == 'APP'
                                          ? AppColors.success
                                          : AppColors.warning,
                                      icon: r.channel == 'APP'
                                          ? Icons.phone_android
                                          : Icons.sms,
                                    ),
                                    if (r.verified) ...[
                                      const SizedBox(width: 6),
                                      const StatusChip(
                                        label: 'Verified',
                                        color: AppColors.success,
                                        icon: Icons.verified,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$date • ${r.latitude.toStringAsFixed(3)}, '
                                  '${r.longitude.toStringAsFixed(3)}',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12),
                                ),
                                if (!r.verified) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _verify(context, ref, r.id),
                                      icon: const Icon(Icons.verified, size: 18),
                                      label: const Text('Verify as credible'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _verify(
      BuildContext context, WidgetRef ref, String reportId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final alert = await ref
          .read(conflictControllerProvider.notifier)
          .verifyAndProcessCommunityReport(reportId);
      messenger.showSnackBar(SnackBar(
        content: Text(alert == null
            ? 'Report verified. Location is outside all risk zones — no alert raised.'
            : 'Report verified and alert raised/updated.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: AppColors.error,
      ));
    }
  }
}

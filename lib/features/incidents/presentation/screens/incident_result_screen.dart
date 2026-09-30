import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/incident_report.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../providers/incident_providers.dart';
import '../widgets/uc02_widgets.dart';

/// UC02-S01 – Screens 5 & 6: Submission result.
///
/// Online → "Report submitted / Synchronized / Pending review".
/// Offline → "Offline – report saved on this device" with sync = Pending and a
/// retry action. "Pending" is only ever shown after the local save succeeded
/// (the submission controller guarantees that before this screen opens).
class IncidentResultScreen extends ConsumerStatefulWidget {
  const IncidentResultScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<IncidentResultScreen> createState() =>
      _IncidentResultScreenState();
}

class _IncidentResultScreenState extends ConsumerState<IncidentResultScreen> {
  StreamSubscription<SyncPhase>? _phaseSub;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    // Keep this screen's report fresh after connectivity-triggered syncs.
    _phaseSub = ref
        .read(syncServiceProvider)
        .phase
        .where((p) => p == SyncPhase.done || p == SyncPhase.failed)
        .listen((_) {
      ref.invalidate(selectedIncidentProvider(widget.reportId));
      ref.invalidate(pendingIncidentsProvider);
    });
  }
  @override
  void dispose() {
    _phaseSub?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await ref
        .read(incidentSubmissionProvider.notifier)
        .retrySync(widget.reportId);
    if (!mounted) return;
    setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(selectedIncidentProvider(widget.reportId));
    final submission = ref.watch(incidentSubmissionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Submitted'),
        leading: const BackButton(),
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load the report: $e')),
        data: (report) {
          if (report == null) {
            return const Center(child: Text('Report not found on this device.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.check_circle, color: AppColors.success, size: 72),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Report submitted',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Reference: ${submission.reference ?? report.id}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _statusRow(
                        'Submission status',
                        const StatusChip(
                            label: 'Submitted',
                            tone: StatusTone.success,
                            icon: Icons.send),
                      ),
                      const Divider(),
                      _statusRow(
                        'Sync status',
                        syncStatusChip(report.syncState),
                      ),
                      const Divider(),
                      _statusRow(
                        'Review status',
                        reviewStatusChip(report.reviewStatus),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (report.syncState != SyncState.synchronized) ...[
                OfflineSavedBanner(),
                const SizedBox(height: 8),
                const Text(
                  'It will synchronize automatically when the signal returns.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _retrying ? null : _retry,
                  icon: _retrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  label: const Text('Retry sync now'),
                ),
              ],
              const SizedBox(height: 20),
              _ReportSummary(report: report),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.incidents),
                icon: const Icon(Icons.list),
                label: const Text('My incident reports'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusRow(String label, Widget chip) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            chip,
          ],
        ),
      );
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report});

  final IncidentReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Report summary'),
            Text('Category: ${report.category.name}'),
            const SizedBox(height: 4),
            Text(
                'Location: ${report.latitude.toStringAsFixed(5)}, '
                '${report.longitude.toStringAsFixed(5)} '
                '(${report.locationSource == LocationSource.gps ? 'GPS' : 'Manual'})'),
            const SizedBox(height: 4),
            Text('Description: ${report.description}'),
            if (report.evidenceOmissionReason != null) ...[
              const SizedBox(height: 4),
              Text('No photo because: ${report.evidenceOmissionReason}'),
            ],
          ],
        ),
      ),
    );
  }
}

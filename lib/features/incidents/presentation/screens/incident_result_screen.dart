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
import '../../domain/incident_categories.dart';
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
  StreamSubscription<bool>? _connectionSub;
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
    _connectionSub =
        ref.read(connectivityServiceProvider).connectionChanges.listen((online) {
      if (!online || _retrying) return;
      final current =
          ref.read(selectedIncidentProvider(widget.reportId)).asData?.value;
      if (current != null && current.syncState != SyncState.synchronized) {
        _retry();
      }
    });
  }
  @override
  void dispose() {
    _phaseSub?.cancel();
    _connectionSub?.cancel();
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
    final pending =
        ref.watch(pendingIncidentsProvider).asData?.value.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident status'),
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
              Icon(
                report.syncState == SyncState.synchronized
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                color: report.syncState == SyncState.synchronized
                    ? AppColors.success
                    : const Color(0xFFD97706),
                size: 72,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  report.syncState == SyncState.synchronized
                      ? 'Incident Submitted'
                      : 'Pending Synchronisation',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              if (_retrying)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Connection restored · synchronizing...'),
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
                            label: 'SUBMITTED',
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
              if (report.syncState == SyncState.synchronized)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 8),
                      Text('SYNCHRONISED',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              if (report.syncState != SyncState.synchronized) ...[
                OfflineSavedBanner(pendingCount: pending),
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
              PrimaryActionButton(
                label: 'OK',
                icon: Icons.check,
                onPressed: () => context.go(AppRoutes.incidents),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.patrol),
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('Continue Patrol'),
                ),
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
            Text(
              'Category: ${IncidentReportCategory.fromShared(report.category).label}',
            ),
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

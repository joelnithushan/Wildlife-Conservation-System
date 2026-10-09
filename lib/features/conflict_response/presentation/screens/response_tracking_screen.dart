import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../../../shared/models/response_assignment.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../domain/acknowledgement_monitor.dart';
import '../providers/conflict_providers.dart';
import '../widgets/lifecycle_timeline.dart';
import '../widgets/status_chip.dart';

/// Screen 7 — Response Tracking (Park Manager). Real-time view of the active
/// response: responder details, notification delivery state with retry,
/// acknowledgement status, escalation triggers with configurable thresholds,
/// and live status transition history.
class ResponseTrackingScreen extends ConsumerStatefulWidget {
  const ResponseTrackingScreen({super.key, required this.alertId});

  final String alertId;

  @override
  ConsumerState<ResponseTrackingScreen> createState() =>
      _ResponseTrackingScreenState();
}

class _ResponseTrackingScreenState
    extends ConsumerState<ResponseTrackingScreen> {
  bool _busy = false;

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : null,
      ));
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _snack(okMessage);
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
    await _run(
      () => ref
          .read(conflictControllerProvider.notifier)
          .resolveAlert(widget.alertId),
      'Alert resolved successfully.',
    );
  }

  Future<void> _retryDelivery(String assignmentId) async {
    await _run(
      () => ref
          .read(conflictControllerProvider.notifier)
          .retryNotificationDelivery(assignmentId),
      'Notification delivery re-attempted and updated.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final alertAsync = ref.watch(alertProvider(widget.alertId));
    final assignmentAsync =
        ref.watch(activeAssignmentProvider(widget.alertId));
    final config = ref.watch(conflictConfigProvider);
    final thresholdMinutes =
        ref.watch(acknowledgementThresholdMinutesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Response Tracking')),
      body: alertAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (alert) {
          if (alert == null) {
            return const Center(child: Text('Alert not found.'));
          }
          final assignment = assignmentAsync.asData?.value;
          final overdue = assignment != null &&
              AcknowledgementMonitor.isOverdue(assignment,
                  now: DateTime.now(), config: config);
          return _content(
            alert,
            assignment,
            overdue,
            thresholdMinutes,
          );
        },
      ),
    );
  }

  Widget _content(
    WildlifeRiskAlert alert,
    ResponseAssignment? assignment,
    bool overdue,
    int thresholdMinutes,
  ) {
    final resolved = alert.status == AlertStatus.resolved;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (resolved) _resolvedBanner(),
        Row(
          children: [
            const Text('Current status: '),
            AlertStatusChip(alert.status),
          ],
        ),
        const SizedBox(height: 12),
        _thresholdSelector(thresholdMinutes, alert),
        const SizedBox(height: 16),
        if (assignment != null) _responderCard(assignment),
        const SizedBox(height: 16),
        const Text('Lifecycle',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        LifecycleTimeline(
          alert: alert,
          assignment: assignment,
          overdue: overdue,
        ),
        const SizedBox(height: 12),
        if (!resolved) ...[
          if (overdue) _escalationActions(),
          _resolveButton(alert, assignment),
          const SizedBox(height: 16),
        ],
        _statusHistory(alert.id),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.go(AppRoutes.conflictResponse),
            child: const Text('Back to Alerts'),
          ),
        ),
      ],
    );
  }

  Widget _thresholdSelector(int currentMinutes, WildlifeRiskAlert alert) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                'Ack Escalation Threshold:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              StatusChip(
                label: '$currentMinutes min',
                color: AppColors.primary,
                icon: Icons.timer,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final mins in [1, 5, 15, 30]) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(mins == 1 ? '1m (Demo)' : '${mins}m'),
                    selected: currentMinutes == mins,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(acknowledgementThresholdMinutesProvider
                                .notifier)
                            .setThreshold(mins);
                        // Trigger check and escalate if active
                        ref
                            .read(conflictControllerProvider.notifier)
                            .checkAndEscalateOverdue(alert.parkId);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _responderCard(ResponseAssignment a) {
    final name = DemoData.users
            .where((u) => u.id == a.responderId)
            .map((u) => u.name)
            .firstOrNull ??
        a.responderId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Responder: $name',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(ConflictLabels.responderRole(a.responderRole),
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusChip(
                  label: ConflictLabels.delivery(a.deliveryState),
                  color: ConflictLabels.deliveryColor(a.deliveryState),
                  icon: a.deliveryState == DeliveryState.delivered
                      ? Icons.check_circle_outline
                      : (a.deliveryState == DeliveryState.pending
                          ? Icons.schedule
                          : Icons.error_outline),
                ),
                if (a.deliveredAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('HH:mm:ss').format(a.deliveredAt!.toLocal()),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
            if (a.deliveryState != DeliveryState.delivered) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _retryDelivery(a.id),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry Notification Delivery'),
              ),
            ],
            if ((a.statusNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: ${a.statusNote}'),
            ],
            if ((a.outcome ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Outcome: ${a.outcome}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _escalationActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatusChip(
            label:
                'Acknowledgement overdue — threshold exceeded. Reassign responder:',
            color: AppColors.error,
            icon: Icons.priority_high,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                context.push(AppRoutes.assignResponderFor(widget.alertId)),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Reassign responder'),
          ),
        ],
      ),
    );
  }

  Widget _resolveButton(WildlifeRiskAlert alert, ResponseAssignment? a) {
    final hasOutcome = (a?.outcome ?? '').trim().isNotEmpty;
    final canResolve =
        alert.status == AlertStatus.responseInProgress && hasOutcome;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (canResolve && !_busy) ? _resolve : null,
            icon: const Icon(Icons.verified),
            label: const Text('Resolve Alert'),
          ),
        ),
        if (!hasOutcome)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Resolve becomes available once the responder records an outcome.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _resolvedBanner() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('Alert resolved',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success)),
          ],
        ),
      );

  Widget _statusHistory(String alertId) {
    final historyAsync = ref.watch(alertStatusHistoryProvider(alertId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.history, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Status Transition History (Audit Log)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        historyAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error loading history: $e'),
          data: (history) {
            if (history.isEmpty) {
              return Text('No status transitions recorded yet.',
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 13));
            }
            return Column(
              children: [
                for (final change in history)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            change.toStatus == AlertStatus.resolved
                                ? Icons.check_circle
                                : Icons.arrow_circle_right_outlined,
                            size: 20,
                            color: ConflictLabels.alertColor(change.toStatus),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    StatusChip(
                                      label: ConflictLabels.alertStatus(
                                          change.toStatus),
                                      color: ConflictLabels.alertColor(
                                          change.toStatus),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat('HH:mm:ss · MMM d')
                                          .format(change.timestamp.toLocal()),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                if ((change.changedBy ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('By: ${change.changedBy}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500)),
                                ],
                                if ((change.reason ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(change.reason!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

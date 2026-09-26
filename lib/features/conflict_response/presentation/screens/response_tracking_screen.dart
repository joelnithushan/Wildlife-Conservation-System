import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Screens 7 & 8 — Response Tracking + Resolved (Park Manager). Shows the full
/// lifecycle, escalation state when acknowledgement is overdue, and the Resolve
/// action once an outcome exists. After resolution it becomes the status-history
/// view.
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

  Future<void> _resolve() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(conflictControllerProvider.notifier)
          .resolveAlert(widget.alertId);
      if (mounted) _snack('Alert resolved.');
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertAsync = ref.watch(alertProvider(widget.alertId));
    final assignmentAsync = ref.watch(activeAssignmentProvider(widget.alertId));

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
                  now: DateTime.now());
          return _content(alert, assignment, overdue);
        },
      ),
    );
  }

  Widget _content(
    WildlifeRiskAlert alert,
    ResponseAssignment? assignment,
    bool overdue,
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
        const SizedBox(height: 8),
        if (resolved)
          _statusHistory()
        else ...[
          if (overdue) _escalationActions(),
          _resolveButton(alert, assignment),
        ],
      ],
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
            const SizedBox(height: 8),
            StatusChip(
              label: ConflictLabels.delivery(a.deliveryState),
              color: ConflictLabels.deliveryColor(a.deliveryState),
              icon: Icons.notifications_active_outlined,
            ),
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
            label: 'No acknowledgement in time — reassign another responder',
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

  Widget _statusHistory() {
    const steps = [
      'NEW',
      'ASSIGNED',
      'ACKNOWLEDGED',
      'RESPONSE_IN_PROGRESS',
      'RESOLVED',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('Status history',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              StatusChip(label: steps[i], color: AppColors.primary),
              if (i < steps.length - 1)
                const Icon(Icons.arrow_forward, size: 16),
            ],
          ],
        ),
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
}

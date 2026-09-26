import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../../../shared/models/response_assignment.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../../../shared/session/current_user.dart';
import '../providers/conflict_providers.dart';
import '../widgets/status_chip.dart';

/// Screens 4–6 — responder-side. A single mobile-first screen that adapts to the
/// active assignment: Assigned → Acknowledge, Acknowledged → Start Response,
/// In Progress → record status/outcome.
class ResponderAssignmentScreen extends ConsumerStatefulWidget {
  const ResponderAssignmentScreen({super.key, required this.alertId});
  final String alertId;

  @override
  ConsumerState<ResponderAssignmentScreen> createState() =>
      _ResponderAssignmentScreenState();
}

class _ResponderAssignmentScreenState
    extends ConsumerState<ResponderAssignmentScreen> {
  final _noteController = TextEditingController();
  final _actionController = TextEditingController();
  String _outcome = _outcomeOptions.first;
  final _otherController = TextEditingController();
  bool _busy = false;

  static const _outcomeOptions = [
    'Animal returned to park',
    'Animal still near risk zone',
    'Residents warned',
    'Other',
  ];

  @override
  void dispose() {
    _noteController.dispose();
    _actionController.dispose();
    _otherController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final alertAsync = ref.watch(alertProvider(widget.alertId));
    final assignmentAsync = ref.watch(activeAssignmentProvider(widget.alertId));

    return Scaffold(
      appBar: AppBar(title: const Text('My Assignment')),
      body: alertAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (alert) {
          if (alert == null) {
            return const Center(child: Text('Alert not found.'));
          }
          return assignmentAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (assignment) {
              if (assignment == null) {
                return const Center(
                    child: Text('No assignment for this alert yet.'));
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _AlertSummary(alert: alert),
                  const SizedBox(height: 16),
                  _body(alert, assignment),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _body(WildlifeRiskAlert alert, ResponseAssignment a) {
    final me = ref.watch(currentUserProvider);
    final isMine = me.id == a.responderId;

    if (a.acknowledgedAt == null) {
      return _acknowledgeView(a, isMine);
    }
    if (a.startedAt == null) {
      return _startView(a);
    }
    if ((a.outcome ?? '').trim().isEmpty) {
      return _inProgressView(a);
    }
    return _doneView(a);
  }

  // --- Screen 4: Assigned → Acknowledge ---
  Widget _acknowledgeView(ResponseAssignment a, bool isMine) {
    final assignedTo = DemoData.users
            .where((u) => u.id == a.responderId)
            .map((u) => u.name)
            .firstOrNull ??
        a.responderId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Status: '),
          const StatusChip(label: 'Assigned', color: AppColors.warning),
        ]),
        const SizedBox(height: 12),
        _kv('Assigned to', '$assignedTo (${ConflictLabels.responderRole(a.responderRole)})'),
        _kv('Assigned at',
            DateFormat('MMM d, HH:mm').format(a.assignedAt.toLocal())),
        _kv('Assigned by', a.assignedBy),
        _kv('Notification', ConflictLabels.delivery(a.deliveryState)),
        const SizedBox(height: 20),
        if (!isMine) ...[
          Text(
            'This assignment belongs to $assignedTo. Acknowledge as that responder to continue.',
            style: const TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _actAs(a.responderId),
            icon: const Icon(Icons.switch_account),
            label: Text('Act as $assignedTo'),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_busy || !isMine)
                ? null
                : () => _run(
                      () => ref
                          .read(conflictControllerProvider.notifier)
                          .acknowledge(a.id),
                      'Acknowledged.',
                    ),
            icon: const Icon(Icons.check),
            label: const Text('Acknowledge'),
          ),
        ),
      ],
    );
  }

  void _actAs(String responderId) {
    final user = DemoData.users.where((u) => u.id == responderId).firstOrNull;
    if (user != null) {
      ref.read(currentUserProvider.notifier).signIn(user);
    }
  }

  // --- Screen 5: Acknowledged → Start Response ---
  Widget _startView(ResponseAssignment a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Status: '),
          const StatusChip(label: 'Acknowledged', color: AppColors.primaryLight),
        ]),
        const SizedBox(height: 12),
        Text(
          'The Park Manager can see you have acknowledged this alert.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        _kv('Acknowledged at',
            DateFormat('MMM d, HH:mm').format(a.acknowledgedAt!.toLocal())),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(
                      () => ref
                          .read(conflictControllerProvider.notifier)
                          .startResponse(a.id),
                      'Response started.',
                    ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Response'),
          ),
        ),
      ],
    );
  }

  // --- Screen 6: In Progress → record status/outcome ---
  Widget _inProgressView(ResponseAssignment a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Status: '),
          const StatusChip(label: 'In Progress', color: AppColors.primary),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Interim status note (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _busy || _noteController.text.trim().isEmpty
                ? null
                : () => _run(
                      () => ref
                          .read(conflictControllerProvider.notifier)
                          .updateStatus(
                            assignmentId: a.id,
                            note: _noteController.text.trim(),
                          ),
                      'Status note saved.',
                    ),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save note'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _actionController,
          decoration: const InputDecoration(
            labelText: 'Action taken',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        const Text('Outcome', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final o in _outcomeOptions)
              ChoiceChip(
                label: Text(o),
                selected: _outcome == o,
                onSelected: (_) => setState(() => _outcome = o),
              ),
          ],
        ),
        if (_outcome == 'Other') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _otherController,
            decoration: const InputDecoration(
              labelText: 'Describe outcome',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : () => _submitOutcome(a),
            icon: const Icon(Icons.done_all),
            label: const Text('Submit Outcome'),
          ),
        ),
      ],
    );
  }

  Future<void> _submitOutcome(ResponseAssignment a) async {
    final outcomeText =
        _outcome == 'Other' ? _otherController.text.trim() : _outcome;
    if (outcomeText.isEmpty) {
      _snack('Please describe the outcome.', error: true);
      return;
    }
    final action = _actionController.text.trim();
    final composed = action.isEmpty ? outcomeText : '$outcomeText — $action';
    await _run(() async {
      final note = _noteController.text.trim();
      if (note.isNotEmpty) {
        await ref
            .read(conflictControllerProvider.notifier)
            .updateStatus(assignmentId: a.id, note: note);
      }
      await ref
          .read(conflictControllerProvider.notifier)
          .recordOutcome(assignmentId: a.id, outcome: composed);
    }, 'Outcome submitted. Awaiting manager resolution.');
  }

  // --- Outcome submitted ---
  Widget _doneView(ResponseAssignment a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.check_circle, color: AppColors.success),
          SizedBox(width: 8),
          Text('Outcome submitted',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        if ((a.statusNote ?? '').isNotEmpty) _kv('Status note', a.statusNote!),
        _kv('Outcome', a.outcome ?? ''),
        _kv('Submitted at',
            DateFormat('MMM d, HH:mm').format(a.completedAt!.toLocal())),
        const SizedBox(height: 12),
        Text(
          'The Park Manager will review the outcome and resolve the alert.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(k,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
            Expanded(
                child: Text(v,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _AlertSummary extends StatelessWidget {
  const _AlertSummary({required this.alert});
  final WildlifeRiskAlert alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ConflictLabels.sourceIcon(alert.source),
                    color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ConflictLabels.source(alert.source),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(
                  label: ConflictLabels.severity(alert.severity),
                  color: ConflictLabels.severityColor(alert.severity),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${alert.latitude.toStringAsFixed(4)}, '
              '${alert.longitude.toStringAsFixed(4)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (alert.riskZoneId != null)
              Text('Risk zone: ${alert.riskZoneId}',
                  style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

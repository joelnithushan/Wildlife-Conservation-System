import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/response_assignment.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import 'status_chip.dart';

/// Vertical lifecycle timeline for an alert, derived from the alert plus its
/// active assignment timestamps (no separate history model needed).
class LifecycleTimeline extends StatelessWidget {
  const LifecycleTimeline({
    super.key,
    required this.alert,
    this.assignment,
    this.overdue = false,
  });

  final WildlifeRiskAlert alert;
  final ResponseAssignment? assignment;
  final bool overdue;

  String _fmt(DateTime? t) =>
      t == null ? '—' : DateFormat('MMM d, HH:mm').format(t.toLocal());

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final steps = <_Step>[
      _Step('Alert created', _fmt(alert.createdAt), true),
      _Step('Responder assigned', _fmt(a?.assignedAt), a != null),
      _Step(
        a?.deliveryState != null
            ? ConflictLabels.delivery(a!.deliveryState)
            : 'Notification',
        _fmt(a?.deliveredAt),
        a?.deliveredAt != null,
      ),
      _Step('Acknowledged', _fmt(a?.acknowledgedAt), a?.acknowledgedAt != null),
      _Step('Response started', _fmt(a?.startedAt), a?.startedAt != null),
      _Step('Outcome recorded', _fmt(a?.completedAt), a?.completedAt != null),
      _Step('Resolved', _fmt(alert.resolvedAt), alert.resolvedAt != null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (overdue)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StatusChip(
              label: 'Acknowledgement overdue — escalated',
              color: AppColors.error,
              icon: Icons.priority_high,
            ),
          ),
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

class _Step {
  const _Step(this.label, this.time, this.done);
  final String label;
  final String time;
  final bool done;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});
  final _Step step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = step.done ? AppColors.primary : Colors.grey.shade400;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                step.done ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: color,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade300),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: TextStyle(
                    fontWeight: step.done ? FontWeight.w600 : FontWeight.w400,
                    color: step.done ? AppColors.textPrimary : Colors.grey,
                  ),
                ),
                Text(
                  step.time,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

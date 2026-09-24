import 'package:flutter/material.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../shared/widgets/status_chip.dart';

/// Status chip specialised for [PatrolStatus], using the shared [StatusChip].
/// Matches the design system: dot for Assigned/In progress, check for Completed.
class PatrolStatusChip extends StatelessWidget {
  const PatrolStatusChip(this.status, {super.key});

  final PatrolStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PatrolStatus.assigned =>
        const StatusChip(label: 'Assigned', tone: StatusTone.info, showDot: true),
      PatrolStatus.inProgress => const StatusChip(
          label: 'In progress', tone: StatusTone.success, showDot: true),
      PatrolStatus.completed => const StatusChip(
          label: 'Completed',
          tone: StatusTone.success,
          icon: Icons.check_circle_outline,
        ),
    };
  }
}

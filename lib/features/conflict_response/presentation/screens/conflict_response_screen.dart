import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';

class ConflictResponseScreen extends ConsumerWidget {
  const ConflictResponseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conflict Response'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AlertBanner(
            severity: 'High',
            color: AppColors.error,
            message: 'No active alerts',
          ),
          const SizedBox(height: 16),
          Text(
            'UC03 — Coordinate Wildlife Conflict Response',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vaishnavi will implement:\n'
            '• Receive / simulate wildlife risk alerts\n'
            '• Create and update alert records\n'
            '• Assign Ranger / Community Liaison\n'
            '• Send notifications\n'
            '• Track and resolve response status',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add_alert),
        label: const Text('New Alert'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.severity,
    required this.color,
    required this.message,
  });

  final String severity;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.crisis_alert, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          Chip(
            label: Text(severity),
            backgroundColor: color.withValues(alpha: 0.15),
            labelStyle: TextStyle(color: color, fontSize: 11),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

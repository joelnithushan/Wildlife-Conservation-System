import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';

class PatrolScreen extends ConsumerWidget {
  const PatrolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrol Operations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {},
            tooltip: 'Sync pending data',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(
            icon: Icons.route,
            label: 'Active Patrol',
            value: 'None',
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            icon: Icons.pending_actions,
            label: 'Assigned',
            value: '—',
            color: AppColors.secondary,
          ),
          const SizedBox(height: 24),
          Text(
            'UC01 — Manage Patrol Operations',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Joel will implement:\n'
            '• View assigned patrols\n'
            '• Start patrol with GPS tracking\n'
            '• Manual waypoint recording\n'
            '• Offline storage + sync\n'
            '• Complete patrol & view coverage',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Patrol'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

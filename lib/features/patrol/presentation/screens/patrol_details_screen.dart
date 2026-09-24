import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/date_extensions.dart';
import '../providers/patrol_providers.dart';
import '../widgets/patrol_status_chip.dart';
import '../widgets/route_preview.dart';

/// Screen 3 – Patrol Details. Start Patrol is available only when assigned.
class PatrolDetailsScreen extends ConsumerWidget {
  const PatrolDetailsScreen({super.key, required this.patrolId});

  final String patrolId;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(patrolRepositoryProvider).startPatrol(patrolId);
      refreshPatrolData(ref);
      if (context.mounted) context.push(AppRoutes.activeFor(patrolId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot start patrol: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patrolAsync = ref.watch(patrolByIdProvider(patrolId));
    final routes = ref.watch(patrolRoutesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Patrol Details')),
      body: patrolAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (patrol) {
          if (patrol == null) {
            return const Center(child: Text('Patrol not found.'));
          }
          final matches = routes.where((r) => r.id == patrol.routeId);
          final route = matches.isEmpty ? null : matches.first;
          final canStart = patrol.status == PatrolStatus.assigned;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RoutePreview(plannedPath: route?.plannedPath ?? const []),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(route?.name ?? patrol.routeId,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  PatrolStatusChip(patrol.status),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow('Route ID', patrol.routeId),
              if (route != null) _InfoRow('Distance', '${route.distanceKm} km'),
              _InfoRow('Scheduled', patrol.scheduledFor.toDisplayDateTime()),
              if (patrol.startedAt != null)
                _InfoRow('Started', patrol.startedAt!.toDisplayDateTime()),
              _InfoRow('Sync state', patrol.syncState.name),
              const SizedBox(height: 24),
              if (patrol.status == PatrolStatus.inProgress)
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.activeFor(patrol.id)),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Resume Patrol'),
                )
              else if (patrol.status == PatrolStatus.completed)
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.summaryFor(patrol.id)),
                  icon: const Icon(Icons.summarize),
                  label: const Text('View Summary'),
                )
              else
                FilledButton.icon(
                  onPressed: canStart ? () => _start(context, ref) : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Patrol'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

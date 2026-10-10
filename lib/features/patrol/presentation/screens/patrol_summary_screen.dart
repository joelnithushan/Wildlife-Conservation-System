import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_extensions.dart';
import '../../../../shared/models/patrol.dart';
import '../../../../shared/models/patrol_position.dart';
import '../providers/patrol_providers.dart';
import '../widgets/route_preview.dart';

/// Screen 8 – Completion summary shown after finishing a patrol.
class PatrolSummaryScreen extends ConsumerWidget {
  const PatrolSummaryScreen({super.key, required this.patrolId});

  final String patrolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patrolAsync = ref.watch(patrolByIdProvider(patrolId));
    final positionsAsync = ref.watch(patrolPositionsProvider(patrolId));
    final pendingAsync = ref.watch(pendingRecordCountProvider);
    final routes = ref.watch(patrolRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrol Summary'),
        automaticallyImplyLeading: false,
      ),
      body: patrolAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (patrol) {
          if (patrol == null) {
            return const Center(child: Text('Patrol not found.'));
          }
          final matches = routes.where((r) => r.id == patrol.routeId);
          final route = matches.isEmpty ? null : matches.first;
          final positions = positionsAsync.value ?? const <PatrolPosition>[];
          final pending = pendingAsync.value ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Icon(Icons.check_circle,
                  color: Colors.green, size: 64),
              const SizedBox(height: 8),
              Center(
                child: Text('Patrol completed',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 16),
              RoutePreview(
                plannedPath: route?.plannedPath ?? const [],
                positions: positions,
              ),
              const SizedBox(height: 16),
              _CoverageRing(percent: patrol.coveragePercent ?? 0),
              const SizedBox(height: 16),
              _SummaryTile('Route', route?.name ?? patrol.routeId),
              _SummaryTile('Duration', _duration(patrol)),
              _SummaryTile('Positions recorded', '${positions.length}'),
              _SummaryTile(
                'Completed at',
                patrol.completedAt?.toDisplayDateTime() ?? '—',
              ),
              _SummaryTile(
                'Sync status',
                patrol.syncState == SyncState.synchronized
                    ? 'Synchronized'
                    : pending > 0
                        ? '$pending pending'
                        : patrol.syncState.name,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.patrol),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _duration(Patrol patrol) {
    if (patrol.startedAt == null || patrol.completedAt == null) return '—';
    final d = patrol.completedAt!.difference(patrol.startedAt!);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

class _CoverageRing extends StatelessWidget {
  const _CoverageRing({required this.percent});
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: (percent / 100).clamp(0.0, 1.0),
                      strokeWidth: 7,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(AppColors.success),
                    ),
                  ),
                  Text('${percent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${percent.toStringAsFixed(0)}% covered',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Text('of the planned route',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // A Row with a Flexible value instead of ListTile.trailing: ListTile throws
    // "trailing widget consumes the entire tile width" when the value is long on
    // narrow screens. This lets long values (e.g. a full date) wrap/ellipsize.
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

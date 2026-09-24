import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/patrol.dart';
import '../../../../shared/providers/providers.dart';
import '../../application/patrol_tracking_controller.dart';
import '../providers/patrol_providers.dart';
import '../widgets/route_preview.dart';
import '../widgets/status_banners.dart';

/// Screen 4 – Patrol In Progress. Live GPS/manual capture, offline handling,
/// sync, and finishing the patrol.
class PatrolInProgressScreen extends ConsumerStatefulWidget {
  const PatrolInProgressScreen({super.key, required this.patrolId});

  final String patrolId;

  @override
  ConsumerState<PatrolInProgressScreen> createState() =>
      _PatrolInProgressScreenState();
}

class _PatrolInProgressScreenState
    extends ConsumerState<PatrolInProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(patrolTrackingControllerProvider.notifier)
        ..attach(widget.patrolId);
      controller.beginTracking();
    });
  }

  Future<void> _finish(Patrol patrol) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => _FinishSheet(),
    );
    if (confirmed != true) return; // Cancelled -> stays inProgress.
    try {
      await ref.read(patrolRepositoryProvider).completePatrol(patrol.id);
      refreshPatrolData(ref);
      // Best-effort sync on completion.
      await ref.read(patrolTrackingControllerProvider.notifier).runSync();
      if (mounted) context.pushReplacement(AppRoutes.summaryFor(patrol.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not complete patrol: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patrolAsync = ref.watch(patrolByIdProvider(widget.patrolId));
    final positionsAsync = ref.watch(patrolPositionsProvider(widget.patrolId));
    final pendingAsync = ref.watch(pendingRecordCountProvider);
    final onlineAsync = ref.watch(isOnlineProvider);
    final tracking = ref.watch(patrolTrackingControllerProvider);
    final routes = ref.watch(patrolRoutesProvider);

    return patrolAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (patrol) {
        if (patrol == null) {
          return const Scaffold(body: Center(child: Text('Patrol not found.')));
        }
        final matches = routes.where((r) => r.id == patrol.routeId);
        final route = matches.isEmpty ? null : matches.first;
        final positions = positionsAsync.value ?? const [];
        final pending = pendingAsync.value ?? 0;
        final isOnline = onlineAsync.value ?? true;

        return Scaffold(
          appBar: AppBar(title: Text(route?.name ?? 'Patrol in progress')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!isOnline)
                OfflineBanner(pendingCount: pending)
              else if (tracking.isSyncing || tracking.syncMessage != null)
                SyncBanner(
                  message: tracking.syncMessage ?? 'Online',
                  isSyncing: tracking.isSyncing,
                ),
              const SizedBox(height: 12),
              RoutePreview(
                plannedPath: route?.plannedPath ?? const [],
                positions: positions,
              ),
              const SizedBox(height: 16),
              _StatsRow(
                positionCount: positions.length,
                pending: pending,
                startedAt: patrol.startedAt,
                showPending: !isOnline && pending > 0,
              ),
              const SizedBox(height: 12),
              if (tracking.gpsUnavailable)
                Card(
                  color: Colors.amber.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.gps_off, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(child: Text(tracking.gpsError!)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(patrolTrackingControllerProvider.notifier)
                        .captureGpsOnce(),
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Mark Waypoint (GPS)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push(AppRoutes.waypointFor(patrol.id)),
                    icon: const Icon(Icons.touch_app),
                    label: const Text('Manual Waypoint'),
                  ),
                  OutlinedButton.icon(
                    onPressed: tracking.isSyncing
                        ? null
                        : () => ref
                            .read(patrolTrackingControllerProvider.notifier)
                            .runSync(),
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync now'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary),
                onPressed: () => _finish(patrol),
                icon: const Icon(Icons.flag),
                label: const Text('Finish Patrol'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.positionCount,
    required this.pending,
    required this.startedAt,
    required this.showPending,
  });

  final int positionCount;
  final int pending;
  final DateTime? startedAt;
  final bool showPending;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'Positions', value: '$positionCount'),
        const SizedBox(width: 12),
        if (showPending)
          _StatCard(label: 'Pending', value: '$pending', highlight: true)
        else
          Expanded(
            child: StreamBuilder<int>(
              stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
              builder: (context, _) {
                final elapsed = startedAt == null
                    ? Duration.zero
                    : DateTime.now().difference(startedAt!);
                return _StatCard(label: 'Elapsed', value: _fmt(elapsed));
              },
            ),
          ),
      ],
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.warning : AppColors.textPrimary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _FinishSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Finish patrol?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'This will complete the patrol and calculate coverage. You cannot '
                'reopen a completed patrol.'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Finish Patrol'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

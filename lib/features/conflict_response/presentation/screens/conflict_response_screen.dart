import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../../../shared/session/current_user.dart';
import '../providers/conflict_providers.dart';
import '../widgets/alert_card.dart';
import 'community_reports_sheet.dart';

/// Screen 1 — Risk Alerts (Park Manager). Lists alerts with source, zone,
/// animal, time and status, supports status filtering, and offers collar/
/// community triggers. Handles loading, empty and error states.
class ConflictResponseScreen extends ConsumerStatefulWidget {
  const ConflictResponseScreen({super.key});

  @override
  ConsumerState<ConflictResponseScreen> createState() =>
      _ConflictResponseScreenState();
}

class _ConflictResponseScreenState
    extends ConsumerState<ConflictResponseScreen> {
  AlertStatus? _filter;

  Future<void> _runTrigger(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _snack('Reading processed.');
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final parkId = ref.watch(currentUserProvider).parkId;
    final alertsAsync = ref.watch(riskAlertsProvider(parkId));
    final zones = ref.watch(riskZonesProvider(parkId)).asData?.value ?? const [];
    final animals = ref.watch(trackedAnimalsProvider).asData?.value ?? const [];

    final zoneName = {for (final z in zones) z.id: z.name};
    final animalCode = {for (final a in animals) a.id: a.code};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Alerts'),
        actions: [
          IconButton(
            tooltip: 'Community reports',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const CommunityReportsSheet(),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(riskAlertsProvider(parkId)),
          ),
        ],
      ),
      floatingActionButton: _SimulateButton(onSelected: _onSimulate),
      body: Column(
        children: [
          _FilterBar(
            selected: _filter,
            onSelected: (s) => setState(() => _filter = s),
          ),
          Expanded(
            child: alertsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(riskAlertsProvider(parkId)),
              ),
              data: (alerts) {
                final filtered = _filter == null
                    ? alerts
                    : alerts.where((a) => a.status == _filter).toList();
                if (filtered.isEmpty) return const _EmptyState();
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(riskAlertsProvider(parkId)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final alert = filtered[i];
                      return AlertCard(
                        alert: alert,
                        zoneName: zoneName[alert.riskZoneId] ?? 'Unknown zone',
                        animalCode: animalCode[alert.animalId],
                        onTap: () =>
                            context.push(AppRoutes.alertDetailsFor(alert.id)),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onSimulate(_SimAction action) {
    final controller = ref.read(conflictControllerProvider.notifier);
    final animalId = DemoData.trackedAnimals.first.id;
    switch (action) {
      case _SimAction.insideZone:
        _runTrigger(() => controller.simulateCollarReading(
              animalId: animalId,
              latitude: DemoData.insideRiskZonePoint.latitude,
              longitude: DemoData.insideRiskZonePoint.longitude,
            ));
      case _SimAction.outsideZone:
        _runTrigger(() => controller.simulateCollarReading(
              animalId: animalId,
              latitude: DemoData.outsideRiskZonePoint.latitude,
              longitude: DemoData.outsideRiskZonePoint.longitude,
            ));
    }
  }
}

enum _SimAction { insideZone, outsideZone }

class _SimulateButton extends StatelessWidget {
  const _SimulateButton({required this.onSelected});
  final void Function(_SimAction) onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SimAction>(
      onSelected: onSelected,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _SimAction.insideZone,
          child: Text('Collar reading inside risk zone'),
        ),
        PopupMenuItem(
          value: _SimAction.outsideZone,
          child: Text('Collar reading outside risk zone'),
        ),
      ],
      child: FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.sensors, color: Colors.white),
        label: const Text('Simulate', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});
  final AlertStatus? selected;
  final void Function(AlertStatus?) onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <(String, AlertStatus?)>[
      ('All', null),
      ('New', AlertStatus.newAlert),
      ('Assigned', AlertStatus.assigned),
      ('Acknowledged', AlertStatus.acknowledged),
      ('In Progress', AlertStatus.responseInProgress),
      ('Resolved', AlertStatus.resolved),
    ];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, value) = items[i];
          return ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('No alerts for this filter.'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

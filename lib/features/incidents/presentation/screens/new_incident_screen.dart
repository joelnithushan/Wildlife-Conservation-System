import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/demo/demo_data.dart';
import '../providers/incident_providers.dart';
import '../widgets/uc02_widgets.dart';

/// UC02-S01 screen 1 — start a field incident from the active patrol.
class NewIncidentScreen extends ConsumerWidget {
  const NewIncidentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patrolAsync = ref.watch(activePatrolSnapshotProvider);
    final form = ref.watch(incidentFormControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        title: const Text('New Field Incident'),
        leading: const BackButton(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Report Field Incident',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Record an incident encountered during patrol.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              patrolAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Could not read the active patrol. $e'),
                data: (patrol) => _PatrolCard(patrol: patrol, form: form),
              ),
              const SizedBox(height: 16),
              const SectionLabel('Field incidents'),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ExampleChip(icon: Icons.gavel, label: 'Snare'),
                  _ExampleChip(icon: Icons.pets, label: 'Carcass'),
                  _ExampleChip(icon: Icons.night_shelter, label: 'Illegal campsite'),
                  _ExampleChip(icon: Icons.directions_walk, label: 'Suspicious footprints'),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryActionButton(
            label: 'Start Report',
            icon: Icons.assignment,
            onPressed: () {
              final patrol = patrolAsync.asData?.value;
              if (patrol != null) {
                ref
                    .read(incidentFormControllerProvider.notifier)
                    .bindPatrol(patrol.id);
              }
              context.push(AppRoutes.incidentType);
            },
          ),
        ),
      ),
    );
  }
}

class _PatrolCard extends StatelessWidget {
  const _PatrolCard({required this.patrol, required this.form});

  final ActivePatrolSnapshot? patrol;
  final IncidentFormState form;

  @override
  Widget build(BuildContext context) {
    final routeName = _routeName(patrol?.routeId);
    final position = form.hasLocation
        ? '${form.latitude!.toStringAsFixed(5)}, ${form.longitude!.toStringAsFixed(5)}'
        : 'Captured with this incident when you record GPS';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.directions_walk, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Current patrol',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Text(patrol == null
                ? 'No active patrol. Start a patrol before submitting.'
                : 'Patrol ${patrol!.id}'),
            const SizedBox(height: 4),
            Text('Route: $routeName'),
            const SizedBox(height: 4),
            Text('Position: $position'),
          ],
        ),
      ),
    );
  }

  String _routeName(String? routeId) {
    if (routeId == null) return 'Not on a route';
    for (final route in DemoData.routes) {
      if (route.id == routeId) return '${route.name} (${route.id})';
    }
    return routeId;
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(label),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.primary),
    );
  }
}

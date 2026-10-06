import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/utils/date_extensions.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/patrol_route.dart';
import '../../../../shared/session/current_user.dart';
import '../providers/patrol_providers.dart';
import '../widgets/route_preview.dart';

/// UC01-S01 – Assign Patrol Route (Park Manager).
class AssignPatrolRouteScreen extends ConsumerStatefulWidget {
  const AssignPatrolRouteScreen({super.key});

  @override
  ConsumerState<AssignPatrolRouteScreen> createState() =>
      _AssignPatrolRouteScreenState();
}

class _AssignPatrolRouteScreenState
    extends ConsumerState<AssignPatrolRouteScreen> {
  PatrolRoute? _route;
  AppUser? _ranger;
  DateTime? _scheduledFor;
  bool _saving = false;

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!mounted) return;
    setState(() {
      _scheduledFor = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 8,
        time?.minute ?? 0,
      );
    });
  }

  String? _validate() {
    if (_route == null) return 'Please select a patrol route.';
    if (_ranger == null) return 'Please select a ranger.';
    if (_scheduledFor == null) return 'Please choose a patrol date and time.';
    if (!(_ranger?.isAvailable ?? false)) {
      return 'Selected ranger is not available.';
    }
    return null;
  }

  Future<void> _assign() async {
    final error = _validate();
    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(patrolRepositoryProvider).assignRoute(
            routeId: _route!.id,
            rangerId: _ranger!.id,
            parkId: _ranger!.parkId,
            scheduledFor: _scheduledFor!,
          );
      refreshPatrolData(ref);
      if (!mounted) return;
      _showSnack('Patrol assigned to ${_ranger!.name}.');
      Navigator.of(context).pop();
    } catch (e) {
      // No partial patrol is created — assignRoute either persists fully or throws.
      if (mounted) _showSnack('Assignment failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(patrolRoutesProvider);
    final rangers = ref.watch(availableRangersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Assign Patrol Route'),
      ),
      body: rangers.isEmpty
          ? const Center(child: Text('No rangers are currently available.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                if (wide) {
                  // Manager web layout: routes left, map + fields right.
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _contextLine(),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child:
                                    ListView(children: [_routeSection(routes)]),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: ListView(children: [
                                  RoutePreview(
                                      plannedPath:
                                          _route?.plannedPath ?? const []),
                                  const SizedBox(height: 16),
                                  _rangerField(rangers),
                                  const SizedBox(height: 16),
                                  _scheduleField(),
                                  const SizedBox(height: 24),
                                  _actions(),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // Ranger/mobile: single column.
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _contextLine(),
                    if (_route != null) ...[
                      RoutePreview(plannedPath: _route!.plannedPath),
                      const SizedBox(height: 16),
                    ],
                    _routeSection(routes),
                    const SizedBox(height: 16),
                    _rangerField(rangers),
                    const SizedBox(height: 16),
                    _scheduleField(),
                    const SizedBox(height: 24),
                    _actions(),
                  ],
                );
              },
            ),
    );
  }

  Widget _contextLine() {
    // Authenticated Park Manager context (no hardcoded name/park).
    final user = ref.watch(currentUserProvider);
    final park =
        user.parkId == DemoData.park.id ? DemoData.park.name : user.parkId;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('${user.role.displayLabel} · $park',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    );
  }

  Widget _routeSection(List<PatrolRoute> routes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Patrol routes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        RadioGroup<PatrolRoute>(
          groupValue: _route,
          onChanged: (v) => setState(() => _route = v),
          child: Column(
            children: [
              for (final r in routes)
                Card(
                  child: RadioListTile<PatrolRoute>(
                    value: r,
                    title: Text('${r.name}  (${r.id})'),
                    subtitle: Text('${r.distanceKm} km · ${r.description}'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rangerField(List<AppUser> rangers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ranger', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<AppUser>(
          initialValue: _ranger,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Select ranger'),
          items: [
            for (final r in rangers)
              DropdownMenuItem(
                value: r,
                child: Text('${r.name}${r.isAvailable ? ' (available)' : ''}'),
              ),
          ],
          onChanged: (v) => setState(() => _ranger = v),
        ),
      ],
    );
  }

  Widget _scheduleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Patrol date', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickDateTime,
          icon: const Icon(Icons.event),
          label: Text(_scheduledFor == null
              ? 'Choose date & time'
              : _scheduledFor!.toDisplayDateTime()),
        ),
      ],
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _saving ? null : _assign,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Assign Patrol'),
          ),
        ),
      ],
    );
  }
}

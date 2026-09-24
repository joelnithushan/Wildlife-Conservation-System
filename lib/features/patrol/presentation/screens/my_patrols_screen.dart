import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../shared/models/patrol.dart';
import '../../../../shared/models/patrol_route.dart';
import '../../../../shared/session/current_user.dart';
import '../providers/patrol_providers.dart';
import '../widgets/patrol_card.dart';

/// UC01-S02 – "My Patrols" (Ranger). Also the entry point for the Park Manager,
/// who gets an "Assign patrol" action. A demo role switcher lets one device act
/// as either actor.
class MyPatrolsScreen extends ConsumerWidget {
  const MyPatrolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isManager = user.role == UserRole.parkManager;
    final patrolsAsync = ref.watch(myPatrolsProvider);
    final routes = ref.watch(patrolRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patrols'),
        actions: [
          _RoleSwitcher(current: user.role),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => refreshPatrolData(ref),
          ),
        ],
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.assignPatrol),
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Assign Patrol'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => refreshPatrolData(ref),
        child: patrolsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(message: '$e', onRetry: () => refreshPatrolData(ref)),
          data: (patrols) {
            if (patrols.isEmpty) {
              return _EmptyState(isManager: isManager);
            }

            final now = DateTime.now();
            bool isToday(DateTime d) =>
                d.year == now.year && d.month == now.month && d.day == now.day;
            final today =
                patrols.where((p) => isToday(p.scheduledFor)).toList();
            final upcoming =
                patrols.where((p) => !isToday(p.scheduledFor)).toList();

            PatrolRoute? routeFor(String id) {
              final m = routes.where((r) => r.id == id);
              return m.isEmpty ? null : m.first;
            }

            Widget card(Patrol patrol) => PatrolCard(
                  patrol: patrol,
                  route: routeFor(patrol.routeId),
                  onTap: () => context.push(AppRoutes.detailsFor(patrol.id)),
                );

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (today.isNotEmpty) ...[
                  const _SectionHeader('Today'),
                  ...today.map(card),
                ],
                if (upcoming.isNotEmpty) ...[
                  const _SectionHeader('Upcoming'),
                  ...upcoming.map(card),
                ],
                const SizedBox(height: 12),
                const _OfflineNote(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoleSwitcher extends ConsumerWidget {
  const _RoleSwitcher({required this.current});
  final UserRole current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<UserRole>(
      tooltip: 'Switch demo role',
      icon: const Icon(Icons.people_alt_outlined),
      onSelected: (role) {
        ref.read(currentUserProvider.notifier).switchRole(role);
        refreshPatrolData(ref);
      },
      itemBuilder: (context) => [
        for (final role in [UserRole.ranger, UserRole.parkManager])
          CheckedPopupMenuItem(
            value: role,
            checked: role == current,
            child: Text(role == UserRole.ranger ? 'Ranger' : 'Park Manager'),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Icon(Icons.download_done, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Assigned patrols and maps are stored on this device, so they open '
              'without a signal.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isManager});
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.route_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        Center(
          child: Text(
            isManager
                ? 'No patrols yet. Tap "Assign Patrol" to create one.'
                : 'No patrols assigned to you yet.',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline, size: 56, color: Colors.red),
        const SizedBox(height: 12),
        Center(child: Text('Could not load patrols.\n$message',
            textAlign: TextAlign.center)),
        const SizedBox(height: 12),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}

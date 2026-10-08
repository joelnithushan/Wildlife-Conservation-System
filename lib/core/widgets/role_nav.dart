import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/session/current_user.dart';
import '../enums/app_enums.dart';
import '../routing/app_router.dart';

/// A single bottom-navigation destination: target route + icons + label.
class NavDest {
  const NavDest(this.route, this.icon, this.selectedIcon, this.label);
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Role-aware bottom-navigation destinations. The last tab is always Profile, so
/// every authenticated area exposes the profile section (requirement). Each
/// role only sees the modules it may open (kept in sync with [AccessPolicy]).
List<NavDest> navDestinationsFor(UserRole role) {
  const patrol = NavDest(
    AppRoutes.patrol, Icons.route_outlined, Icons.route, 'Patrol');
  const incidents = NavDest(AppRoutes.incidents,
      Icons.report_gmailerrorred_outlined, Icons.report, 'Incidents');
  const response = NavDest(AppRoutes.conflictResponse,
      Icons.crisis_alert_outlined, Icons.crisis_alert, 'Response');
  const reports = NavDest(AppRoutes.analytics, Icons.insights_outlined,
      Icons.insights, 'Reports');
  const profile = NavDest(
    AppRoutes.profile, Icons.person_outline, Icons.person, 'Profile');

  switch (role) {
    case UserRole.parkManager:
      return const [
        NavDest(AppRoutes.managerDashboard, Icons.dashboard_outlined,
            Icons.dashboard, 'Home'),
        incidents,
        response,
        reports,
        profile,
      ];
    case UserRole.ranger:
      return const [
        NavDest(AppRoutes.rangerDashboard, Icons.dashboard_outlined,
            Icons.dashboard, 'Home'),
        patrol,
        incidents,
        response,
        profile,
      ];
    case UserRole.communityLiaisonOfficer:
      return const [
        NavDest(AppRoutes.cloDashboard, Icons.dashboard_outlined,
            Icons.dashboard, 'Home'),
        response,
        profile,
      ];
    case UserRole.conservationResearcher:
      return const [
        NavDest(AppRoutes.researcherDashboard, Icons.dashboard_outlined,
            Icons.dashboard, 'Home'),
        reports,
        profile,
      ];
    case UserRole.admin:
      return const [
        NavDest(AppRoutes.adminDashboard, Icons.group_outlined, Icons.group,
            'Users'),
        profile,
      ];
  }
}

/// WildGuard bottom navigation bar, shared by the dashboards, the module shell
/// and the profile screen so the navbar stays consistent everywhere.
class WildGuardNavBar extends ConsumerWidget {
  const WildGuardNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider).role;
    final dests = navDestinationsFor(role);
    // Defensive: `GoRouterState.of` throws if no GoRouter is in the tree (e.g.
    // isolated widget tests). Degrade gracefully instead of crashing.
    String location;
    try {
      location = GoRouterState.of(context).uri.path;
    } catch (_) {
      location = '';
    }

    var index = dests.indexWhere((d) => _isActive(location, d.route));
    if (index < 0) index = 0;

    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) {
        final target = dests[i].route;
        if (target == location) return;
        try {
          context.go(target);
        } catch (_) {
          // No router available (isolated test) — ignore.
        }
      },
      destinations: [
        for (final d in dests)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
      ],
    );
  }

  bool _isActive(String location, String route) {
    if (location == route) return true;
    // Highlight a tab when viewing one of its detail sub-routes.
    if (route != AppRoutes.home && route != AppRoutes.profile) {
      return location.startsWith('$route/');
    }
    return false;
  }
}

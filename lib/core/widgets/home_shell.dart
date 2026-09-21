import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route),
      label: 'Patrol',
    ),
    NavigationDestination(
      icon: Icon(Icons.warning_amber_outlined),
      selectedIcon: Icon(Icons.warning_amber),
      label: 'Incidents',
    ),
    NavigationDestination(
      icon: Icon(Icons.crisis_alert_outlined),
      selectedIcon: Icon(Icons.crisis_alert),
      label: 'Response',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Analytics',
    ),
  ];

  static const _routes = [
    AppRoutes.patrol,
    AppRoutes.incidents,
    AppRoutes.conflictResponse,
    AppRoutes.analytics,
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final idx = _routes.indexOf(location);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => context.go(_routes[i]),
        destinations: _destinations,
      ),
    );
  }
}

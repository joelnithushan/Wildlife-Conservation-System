import 'package:flutter/material.dart';

import 'role_nav.dart';

/// Wraps the bottom-nav module screens (patrol / incidents / response /
/// analytics) with the shared role-aware [WildGuardNavBar] so the navbar is
/// identical to the one shown on the dashboards and profile.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const WildGuardNavBar(),
    );
  }
}

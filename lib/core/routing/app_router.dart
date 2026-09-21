import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/conflict_response/presentation/screens/conflict_response_screen.dart';
import '../../features/incidents/presentation/screens/incidents_screen.dart';
import '../../features/patrol/presentation/screens/patrol_screen.dart';
import '../widgets/home_shell.dart';

part 'app_router.g.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const patrol = '/patrol';
  static const incidents = '/incidents';
  static const conflictResponse = '/conflict-response';
  static const analytics = '/analytics';
}

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    routes: [
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PatrolScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.patrol,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PatrolScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.incidents,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: IncidentsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.conflictResponse,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ConflictResponseScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AnalyticsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}

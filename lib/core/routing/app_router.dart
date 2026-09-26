import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/conflict_response/presentation/screens/alert_details_screen.dart';
import '../../features/conflict_response/presentation/screens/assign_responder_screen.dart';
import '../../features/conflict_response/presentation/screens/conflict_response_screen.dart';
import '../../features/conflict_response/presentation/screens/responder_assignment_screen.dart';
import '../../features/conflict_response/presentation/screens/response_tracking_screen.dart';
import '../../features/incidents/presentation/screens/incidents_screen.dart';
import '../../features/patrol/presentation/screens/assign_patrol_route_screen.dart';
import '../../features/patrol/presentation/screens/manual_waypoint_screen.dart';
import '../../features/patrol/presentation/screens/my_patrols_screen.dart';
import '../../features/patrol/presentation/screens/patrol_details_screen.dart';
import '../../features/patrol/presentation/screens/patrol_in_progress_screen.dart';
import '../../features/patrol/presentation/screens/patrol_summary_screen.dart';
import '../widgets/home_shell.dart';

part 'app_router.g.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const patrol = '/patrol';
  static const incidents = '/incidents';
  static const conflictResponse = '/conflict-response';
  static const analytics = '/analytics';

  // UC01 patrol flow (outside the bottom-nav shell).
  static const assignPatrol = '/assign-patrol';
  static const patrolDetails = '/patrol-details/:id';
  static const patrolActive = '/patrol-active/:id';
  static const patrolWaypoint = '/patrol-waypoint/:id';
  static const patrolSummary = '/patrol-summary/:id';

  static String detailsFor(String id) => '/patrol-details/$id';
  static String activeFor(String id) => '/patrol-active/$id';
  static String waypointFor(String id) => '/patrol-waypoint/$id';
  static String summaryFor(String id) => '/patrol-summary/$id';

  // UC03 conflict-response flow (outside the bottom-nav shell).
  static const alertDetails = '/alert-details/:id';
  static const assignResponder = '/assign-responder/:id';
  static const responderAssignment = '/responder-assignment/:id';
  static const responseTracking = '/response-tracking/:id';

  static String alertDetailsFor(String id) => '/alert-details/$id';
  static String assignResponderFor(String id) => '/assign-responder/$id';
  static String responderAssignmentFor(String id) =>
      '/responder-assignment/$id';
  static String responseTrackingFor(String id) => '/response-tracking/$id';
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
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MyPatrolsScreen()),
          ),
          GoRoute(
            path: AppRoutes.patrol,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MyPatrolsScreen()),
          ),
          GoRoute(
            path: AppRoutes.incidents,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: IncidentsScreen()),
          ),
          GoRoute(
            path: AppRoutes.conflictResponse,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ConflictResponseScreen()),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AnalyticsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.assignPatrol,
        builder: (context, state) => const AssignPatrolRouteScreen(),
      ),
      GoRoute(
        path: AppRoutes.patrolDetails,
        builder: (context, state) =>
            PatrolDetailsScreen(patrolId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.patrolActive,
        builder: (context, state) =>
            PatrolInProgressScreen(patrolId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.patrolWaypoint,
        builder: (context, state) =>
            ManualWaypointScreen(patrolId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.patrolSummary,
        builder: (context, state) =>
            PatrolSummaryScreen(patrolId: state.pathParameters['id']!),
      ),

      // UC03 – Coordinate Wildlife Conflict Response
      GoRoute(
        path: AppRoutes.alertDetails,
        builder: (context, state) =>
            AlertDetailsScreen(alertId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.assignResponder,
        builder: (context, state) =>
            AssignResponderScreen(alertId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.responderAssignment,
        builder: (context, state) =>
            ResponderAssignmentScreen(alertId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.responseTracking,
        builder: (context, state) =>
            ResponseTrackingScreen(alertId: state.pathParameters['id']!),
      ),
    ],
  );
}

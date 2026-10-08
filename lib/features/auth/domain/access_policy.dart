import '../../../core/enums/app_enums.dart';
import '../../../core/routing/app_router.dart';

/// Centralized role-based access policy.
///
/// This is the single source of truth for "which role may open which route" and
/// "where each role lands after sign-in". Keeping it here (pure, no Flutter
/// dependencies) means the router guard and the unit tests share exactly the
/// same rules — role checks are never scattered through individual widgets.
abstract final class AccessPolicy {
  /// The dashboard a user of [role] should land on after signing in.
  static String homeRoute(UserRole role) => switch (role) {
        UserRole.parkManager => AppRoutes.managerDashboard,
        UserRole.ranger => AppRoutes.rangerDashboard,
        UserRole.communityLiaisonOfficer => AppRoutes.cloDashboard,
        UserRole.conservationResearcher => AppRoutes.researcherDashboard,
        UserRole.admin => AppRoutes.adminDashboard,
      };

  /// Routes any authenticated user may open regardless of role.
  static const _universal = <String>{
    AppRoutes.profile,
    AppRoutes.accessDenied,
    AppRoutes.accountIssue,
  };

  /// Parametrized patrol *view* routes (viewing an assigned patrol). These are
  /// distinct from `/assign-patrol`, which creates a patrol (manager only).
  static const _patrolViewPrefixes = <String>[
    '/patrol-details/',
    '/patrol-active/',
    '/patrol-waypoint/',
    '/patrol-summary/',
  ];

  /// Conflict-response feature routes (list + parametrized detail flow).
  static const _conflictPrefixes = <String>[
    AppRoutes.conflictResponse,
    '/alert-details/',
    '/assign-responder/',
    '/responder-assignment/',
    '/response-tracking/',
  ];

  /// Whether [role] is permitted to open [location].
  static bool canAccess(UserRole role, String location) {
    if (_universal.contains(location)) return true;

    switch (role) {
      case UserRole.parkManager:
        // Manager oversees every business module (assign patrol, incident
        // review, conflict response, reports) — but NOT the admin console;
        // account management is reserved for UserRole.admin (AGENTS.md §35).
        return !location.startsWith('/admin');

      case UserRole.ranger:
        const exact = {
          AppRoutes.rangerDashboard,
          AppRoutes.home,
          AppRoutes.patrol,
          AppRoutes.incidents,
        };
        return exact.contains(location) ||
            _startsWithAny(location, _patrolViewPrefixes) ||
            _startsWithAny(location, _conflictPrefixes);

      case UserRole.communityLiaisonOfficer:
        if (location == AppRoutes.cloDashboard) return true;
        return _startsWithAny(location, _conflictPrefixes);

      case UserRole.conservationResearcher:
        const exact = {
          AppRoutes.researcherDashboard,
          AppRoutes.analytics,
        };
        return exact.contains(location);

      case UserRole.admin:
        // System admin only manages accounts; no business-UC routes.
        return location == AppRoutes.adminDashboard ||
            location.startsWith('/admin/');
    }
  }

  static bool _startsWithAny(String location, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (location == prefix || location.startsWith(prefix)) return true;
    }
    return false;
  }
}

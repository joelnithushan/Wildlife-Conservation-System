import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/routing/app_router.dart';
import 'package:wildlife_conservation_system/features/auth/domain/access_policy.dart';

void main() {
  group('AccessPolicy.homeRoute (role → dashboard)', () {
    test('11. Park Manager lands on the Manager Dashboard', () {
      expect(AccessPolicy.homeRoute(UserRole.parkManager),
          AppRoutes.managerDashboard);
    });

    test('12. Ranger lands on the Ranger Dashboard', () {
      expect(AccessPolicy.homeRoute(UserRole.ranger), AppRoutes.rangerDashboard);
    });

    test('13. CLO lands on the CLO Dashboard', () {
      expect(AccessPolicy.homeRoute(UserRole.communityLiaisonOfficer),
          AppRoutes.cloDashboard);
    });

    test('14. Researcher lands on the Researcher Dashboard', () {
      expect(AccessPolicy.homeRoute(UserRole.conservationResearcher),
          AppRoutes.researcherDashboard);
    });

    test('15. Admin lands on the Admin Dashboard', () {
      expect(AccessPolicy.homeRoute(UserRole.admin), AppRoutes.adminDashboard);
    });
  });

  group('AccessPolicy.canAccess (role guards)', () {
    test('16. Ranger is blocked from the manager assign-patrol route', () {
      expect(AccessPolicy.canAccess(UserRole.ranger, AppRoutes.assignPatrol),
          isFalse);
    });

    test('Ranger CAN open the incident creation flow (UC02-S01)', () {
      // Regression: the guard previously allowed only the exact /incidents list,
      // so "Report Incident" (/incidents/new) hit Access Denied on device.
      for (final route in const [
        AppRoutes.newIncident, // /incidents/new
        AppRoutes.incidentType,
        AppRoutes.incidentEvidence,
        AppRoutes.incidentLocation,
        AppRoutes.incidentReview,
        '/incidents/result/abc123',
      ]) {
        expect(AccessPolicy.canAccess(UserRole.ranger, route), isTrue,
            reason: 'ranger must reach $route to record an incident');
      }
    });

    test('Ranger is still blocked from the manager incident review queue', () {
      expect(
          AccessPolicy.canAccess(UserRole.ranger, AppRoutes.incidentReviewQueue),
          isFalse);
      expect(
          AccessPolicy.canAccess(UserRole.ranger, '/incidents/review/abc123'),
          isFalse);
    });

    test('17. Researcher is blocked from patrol management', () {
      expect(AccessPolicy.canAccess(
          UserRole.conservationResearcher, AppRoutes.patrol), isFalse);
      expect(AccessPolicy.canAccess(
          UserRole.conservationResearcher, AppRoutes.assignPatrol), isFalse);
    });

    test('18. Manager is allowed into every module', () {
      for (final loc in [
        AppRoutes.assignPatrol,
        AppRoutes.incidents,
        AppRoutes.conflictResponse,
        AppRoutes.analytics,
        AppRoutes.managerDashboard,
      ]) {
        expect(AccessPolicy.canAccess(UserRole.parkManager, loc), isTrue,
            reason: 'manager should access $loc');
      }
    });

    test('Ranger may view patrols, report incidents and handle responses', () {
      expect(AccessPolicy.canAccess(UserRole.ranger, AppRoutes.patrol), isTrue);
      expect(AccessPolicy.canAccess(UserRole.ranger, '/patrol-details/p1'),
          isTrue);
      expect(AccessPolicy.canAccess(UserRole.ranger, AppRoutes.incidents),
          isTrue);
      expect(AccessPolicy.canAccess(UserRole.ranger, AppRoutes.conflictResponse),
          isTrue);
      expect(AccessPolicy.canAccess(UserRole.ranger, AppRoutes.analytics),
          isFalse);
    });

    test('CLO may only handle conflict responses', () {
      expect(AccessPolicy.canAccess(
          UserRole.communityLiaisonOfficer, AppRoutes.conflictResponse), isTrue);
      expect(AccessPolicy.canAccess(
          UserRole.communityLiaisonOfficer, AppRoutes.incidents), isFalse);
      expect(AccessPolicy.canAccess(
          UserRole.communityLiaisonOfficer, AppRoutes.assignPatrol), isFalse);
    });

    test('Researcher may only open reports', () {
      expect(AccessPolicy.canAccess(
          UserRole.conservationResearcher, AppRoutes.analytics), isTrue);
      expect(AccessPolicy.canAccess(
          UserRole.conservationResearcher, AppRoutes.conflictResponse), isFalse);
    });

    test('every authenticated role may open profile & access-denied', () {
      for (final role in UserRole.values) {
        expect(AccessPolicy.canAccess(role, AppRoutes.profile), isTrue);
        expect(AccessPolicy.canAccess(role, AppRoutes.accessDenied), isTrue);
      }
    });

    test('Admin may open the account-management routes', () {
      expect(AccessPolicy.canAccess(UserRole.admin, AppRoutes.adminDashboard),
          isTrue);
      expect(AccessPolicy.canAccess(UserRole.admin, AppRoutes.adminUserNew),
          isTrue);
      expect(
          AccessPolicy.canAccess(
              UserRole.admin, AppRoutes.adminUserEditFor('u1')),
          isTrue);
    });

    test('Admin is blocked from business-use-case routes', () {
      for (final loc in [
        AppRoutes.assignPatrol,
        AppRoutes.patrol,
        AppRoutes.incidents,
        AppRoutes.conflictResponse,
        AppRoutes.analytics,
      ]) {
        expect(AccessPolicy.canAccess(UserRole.admin, loc), isFalse,
            reason: 'admin should not access $loc');
      }
    });

    test('Non-admin roles are blocked from the admin console', () {
      for (final role in [
        UserRole.parkManager,
        UserRole.ranger,
        UserRole.communityLiaisonOfficer,
        UserRole.conservationResearcher,
      ]) {
        expect(AccessPolicy.canAccess(role, AppRoutes.adminDashboard), isFalse,
            reason: '$role should not access the admin console');
      }
    });
  });
}

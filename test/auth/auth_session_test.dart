import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/auth/domain/auth_failure.dart';
import 'package:wildlife_conservation_system/features/auth/domain/auth_session.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';

void main() {
  group('ProfileIssue Enum Tests', () {
    test('Should return the correct message for ProfileIssue.missing', () {
      // Positive/Edge Case
      const issue = ProfileIssue.missing;
      expect(issue.message, 'Your account is authenticated, but no WildGuard profile was found.');
    });

    test('Should return the correct message for ProfileIssue.inactive', () {
      // Negative Case (User account deactivated)
      const issue = ProfileIssue.inactive;
      expect(issue.message, 'This account has been disabled. Please contact the system administrator.');
    });

    test('Should return the correct message for ProfileIssue.unsupportedRole', () {
      // Error Case (User account role is unsupported)
      const issue = ProfileIssue.unsupportedRole;
      expect(issue.message, 'Your account role is not recognised. Please contact the system administrator.');
    });

    test('Should return the correct message for ProfileIssue.incomplete', () {
      const issue = ProfileIssue.incomplete;
      expect(issue.message, 'Your WildGuard profile is incomplete. Please contact the system administrator.');
    });
  });

  group('AuthSession State Tests', () {
    test('AuthInitial should have empty props', () {
      const state = AuthInitial();
      expect(state.props, isEmpty);
    });

    test('AuthUnauthenticated should maintain failure in props', () {
      const failure = AuthFailure.network;
      const state = AuthUnauthenticated(failure: failure);
      
      expect(state.props, [failure]);
      expect(state.failure, equals(failure));
    });

    test('Authenticated state should maintain user data', () {
      const mockUser = AppUser(
        id: 'user123',
        name: 'John Doe',
        email: 'john@example.com',
        role: UserRole.ranger,
        parkId: 'park1',
      );
      
      const state = Authenticated(mockUser);
      
      expect(state.props, [mockUser]);
      expect(state.user, equals(mockUser));
      expect(state.user.role, equals(UserRole.ranger));
    });

    test('AuthProfileError should maintain issue in props', () {
      const state = AuthProfileError(ProfileIssue.missing);
      
      expect(state.props, [ProfileIssue.missing]);
      expect(state.issue, equals(ProfileIssue.missing));
    });
  });
}

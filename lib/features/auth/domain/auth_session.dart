import 'package:equatable/equatable.dart';

import '../../../shared/models/app_user.dart';
import 'auth_failure.dart';

/// Why an authenticated Firebase account cannot be used as a WildGuard user.
enum ProfileIssue {
  missing,
  inactive,
  unsupportedRole,
  incomplete;

  String get message => switch (this) {
        ProfileIssue.missing =>
          'Your account is authenticated, but no WildGuard profile was found.',
        ProfileIssue.inactive =>
          'This account has been disabled. Please contact the system administrator.',
        ProfileIssue.unsupportedRole =>
          'Your account role is not recognised. Please contact the system administrator.',
        ProfileIssue.incomplete =>
          'Your WildGuard profile is incomplete. Please contact the system administrator.',
      };
}

/// The authentication state that drives routing and guards.
sealed class AuthSession extends Equatable {
  const AuthSession();

  @override
  List<Object?> get props => [];
}

/// Startup / session-restore in progress. The splash / loading screen shows.
class AuthInitial extends AuthSession {
  const AuthInitial();
}

/// No Firebase user signed in.
class AuthUnauthenticated extends AuthSession {
  const AuthUnauthenticated({this.failure});

  /// A login attempt just failed (shown on the login screen).
  final AuthFailure? failure;

  @override
  List<Object?> get props => [failure];
}

/// Firebase user signed in; the Firestore profile is loading.
class AuthLoadingProfile extends AuthSession {
  const AuthLoadingProfile();
}

/// Fully authenticated with a valid WildGuard profile.
class Authenticated extends AuthSession {
  const Authenticated(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

/// Signed in to Firebase but the WildGuard profile is missing/invalid/disabled.
class AuthProfileError extends AuthSession {
  const AuthProfileError(this.issue);

  final ProfileIssue issue;

  @override
  List<Object?> get props => [issue];
}

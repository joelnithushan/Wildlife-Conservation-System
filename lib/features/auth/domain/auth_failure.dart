/// User-facing authentication failures.
///
/// Firebase exception codes are mapped to these cases so the UI never shows a
/// raw Firebase message. Each case carries a friendly [message].
enum AuthFailure {
  invalidCredentials("Incorrect email or password."),
  network("Unable to connect. Check your internet connection."),
  tooManyRequests("Too many sign-in attempts. Please try again later."),
  userDisabled("This account has been disabled."),
  profileMissing(
      "Your account is authenticated, but no WildGuard profile was found."),
  profileInactive(
      "Your WildGuard account is inactive. Please contact the system administrator."),
  unsupportedRole(
      "Your WildGuard account role is not recognised. Please contact the system administrator."),
  invalidEmail("Please enter a valid email address."),
  unknown("Unable to sign in. Please try again.");

  const AuthFailure(this.message);

  /// The message safe to display to the user.
  final String message;

  /// Maps a `firebase_auth` `FirebaseAuthException.code` to a friendly failure.
  ///
  /// Kept independent of the `firebase_auth` package so it can be unit-tested
  /// without Firebase and reused from a fake auth service.
  static AuthFailure fromFirebaseAuthCode(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'wrong-password':
      case 'user-not-found':
      case 'INVALID_LOGIN_CREDENTIALS':
        return AuthFailure.invalidCredentials;
      case 'invalid-email':
        return AuthFailure.invalidEmail;
      case 'user-disabled':
        return AuthFailure.userDisabled;
      case 'too-many-requests':
        return AuthFailure.tooManyRequests;
      case 'network-request-failed':
        return AuthFailure.network;
      default:
        return AuthFailure.unknown;
    }
  }
}

/// Thrown by the auth layer so controllers can surface an [AuthFailure] without
/// leaking Firebase types into the presentation layer.
class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  String get message => failure.message;

  @override
  String toString() => 'AuthException(${failure.name}): ${failure.message}';
}

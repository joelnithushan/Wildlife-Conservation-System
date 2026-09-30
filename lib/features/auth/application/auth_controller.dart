import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/demo/demo_data.dart';
import '../../../shared/providers/providers.dart';
import '../data/auth_service.dart';
import '../data/user_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_session.dart';

/// Raw `firebase_auth` instance. Only touched when Firebase initialized.
final firebaseAuthProvider =
    Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

/// Authentication gateway. `null` when Firebase is not configured, in which case
/// the app runs in offline/demo mode (see [AuthController.build]).
final authServiceProvider = Provider<AuthService?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  return FirebaseAuthService(ref.watch(firebaseAuthProvider));
});

/// WildGuard profile repository. `null` when Firebase is not configured.
final userRepositoryProvider = Provider<UserRepository?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  return FirestoreUserRepository();
});

/// The single source of truth for authentication state used by the router guard
/// and auth screens.
final authControllerProvider =
    NotifierProvider<AuthController, AuthSession>(AuthController.new);

/// Convenience alias for reading the active session.
final currentSessionProvider = authControllerProvider;

/// Owns the sign-in / sign-out / password-reset flow and converts Firebase
/// errors into user-friendly [AuthSession] / [AuthFailure] states.
class AuthController extends Notifier<AuthSession> {
  @override
  AuthSession build() {
    final auth = ref.watch(authServiceProvider);

    // Firebase not configured → offline/demo mode. Mirror the demo session so
    // the existing UC01 flow, the demo role switcher and tests keep working
    // without a live backend.
    if (auth == null) {
      return Authenticated(ref.watch(currentUserProvider));
    }

    // Restore any persisted Firebase session and react to sign-in/out.
    final sub = auth.authStateChanges().listen(_onIdentityChanged);
    ref.onDispose(sub.cancel);
    return const AuthInitial();
  }

  // --- Stream-driven (session restore / external sign-out) ---------------

  Future<void> _onIdentityChanged(AuthIdentity? identity) async {
    if (identity == null) {
      if (state is! AuthUnauthenticated) state = const AuthUnauthenticated();
      return;
    }
    // An interactive sign-in already drives loading/authenticated; don't
    // double-load or clobber it.
    if (state is AuthLoadingProfile || state is Authenticated) return;
    await _loadProfile(identity, treatErrorAsProfileIssue: true);
  }

  // --- Interactive actions ------------------------------------------------

  /// Signs in with email + password. Returns `null` on success or the
  /// [AuthFailure] to display on the login screen.
  Future<AuthFailure?> signIn({
    required String email,
    required String password,
  }) async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) return AuthFailure.unknown;

    state = const AuthLoadingProfile();
    try {
      final identity = await auth.signIn(email: email, password: password);
      return await _loadProfile(identity, treatErrorAsProfileIssue: false);
    } on AuthException catch (e) {
      state = AuthUnauthenticated(failure: e.failure);
      return e.failure;
    } catch (_) {
      state = const AuthUnauthenticated(failure: AuthFailure.unknown);
      return AuthFailure.unknown;
    }
  }

  /// Sends a password-reset email. Returns `null` on success or the failure.
  Future<AuthFailure?> sendPasswordReset(String email) async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) return AuthFailure.unknown;
    try {
      await auth.sendPasswordResetEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.failure;
    } catch (_) {
      return AuthFailure.unknown;
    }
  }

  /// Re-attempts loading the profile for the current identity (Account Issue
  /// screen "Retry").
  Future<void> retryProfile() async {
    final auth = ref.read(authServiceProvider);
    final identity = auth?.currentIdentity;
    if (identity == null) {
      state = const AuthUnauthenticated();
      return;
    }
    state = const AuthLoadingProfile();
    await _loadProfile(identity, treatErrorAsProfileIssue: true);
  }

  /// Signs out and clears the in-memory session.
  Future<void> signOut() async {
    final auth = ref.read(authServiceProvider);
    await auth?.signOut();
    // Reset the shared session subject so no user-specific state lingers.
    ref.read(currentUserProvider.notifier).signIn(DemoData.parkManager);
    state = const AuthUnauthenticated();
  }

  // --- Profile loading ----------------------------------------------------

  /// Loads + validates the Firestore profile. Returns `null` on success or a
  /// failure. On a transient error, [treatErrorAsProfileIssue] decides whether
  /// to route to the Account Issue screen (session restore) or keep the user on
  /// the login screen (interactive sign-in).
  Future<AuthFailure?> _loadProfile(
    AuthIdentity identity, {
    required bool treatErrorAsProfileIssue,
  }) async {
    final repo = ref.read(userRepositoryProvider);
    if (repo == null) {
      state = const AuthProfileError(ProfileIssue.missing);
      return AuthFailure.profileMissing;
    }

    try {
      final result = await repo.getUserProfile(identity.uid);
      if (result.isOk) {
        ref.read(currentUserProvider.notifier).signIn(result.user!);
        state = Authenticated(result.user!);
        return null;
      }
      final issue = result.issue!;
      state = AuthProfileError(issue);
      return _issueToFailure(issue);
    } catch (_) {
      // Transient Firestore/network error — never auto sign-out.
      if (treatErrorAsProfileIssue) {
        state = const AuthProfileError(ProfileIssue.missing);
      } else {
        state = const AuthUnauthenticated(failure: AuthFailure.network);
      }
      return AuthFailure.network;
    }
  }

  AuthFailure _issueToFailure(ProfileIssue issue) => switch (issue) {
        ProfileIssue.missing => AuthFailure.profileMissing,
        ProfileIssue.inactive => AuthFailure.profileInactive,
        ProfileIssue.unsupportedRole => AuthFailure.unsupportedRole,
        ProfileIssue.incomplete => AuthFailure.profileMissing,
      };
}

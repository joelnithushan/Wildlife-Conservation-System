import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_failure.dart';

/// Minimal identity exposed to the rest of the app. Deliberately does NOT leak
/// the `firebase_auth` `User` type so the presentation/application layers never
/// depend on Firebase directly.
class AuthIdentity {
  const AuthIdentity({required this.uid, required this.email});

  final String uid;
  final String email;
}

/// Authentication gateway: identity & session only (no business profile).
///
/// The WildGuard profile / role lives in Firestore and is loaded separately by
/// [UserRepository]. This keeps Firebase Auth credentials and business profile
/// logic in two clean, independently testable classes.
abstract class AuthService {
  /// Emits the current identity, or `null` when signed out. Fires on every
  /// sign-in / sign-out and once on startup with the restored session.
  Stream<AuthIdentity?> authStateChanges();

  /// The currently signed-in identity, if any (synchronous snapshot).
  AuthIdentity? get currentIdentity;

  /// Signs in with email + password. Throws [AuthException] on failure.
  Future<AuthIdentity> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Sends a password-reset email. Throws [AuthException] on failure. To avoid
  /// leaking whether an address is registered, "user not found" completes
  /// normally.
  Future<void> sendPasswordResetEmail(String email);
}

/// [AuthService] backed by `firebase_auth`.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth])
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  AuthIdentity? _toIdentity(User? user) => user == null
      ? null
      : AuthIdentity(uid: user.uid, email: user.email ?? '');

  @override
  Stream<AuthIdentity?> authStateChanges() =>
      _auth.authStateChanges().map(_toIdentity);

  @override
  AuthIdentity? get currentIdentity => _toIdentity(_auth.currentUser);

  @override
  Future<AuthIdentity> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final identity = _toIdentity(credential.user);
      if (identity == null) throw const AuthException(AuthFailure.unknown);
      return identity;
    } on FirebaseAuthException catch (e) {
      throw AuthException(AuthFailure.fromFirebaseAuthCode(e.code));
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Don't reveal whether the address is registered.
      if (e.code == 'user-not-found') return;
      throw AuthException(AuthFailure.fromFirebaseAuthCode(e.code));
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }
}

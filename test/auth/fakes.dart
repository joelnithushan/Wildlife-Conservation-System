import 'dart:async';

import 'package:wildlife_conservation_system/features/auth/data/auth_service.dart';
import 'package:wildlife_conservation_system/features/auth/data/user_repository.dart';
import 'package:wildlife_conservation_system/features/auth/domain/auth_failure.dart';
import 'package:wildlife_conservation_system/features/auth/domain/auth_session.dart';

/// In-memory [AuthService] for unit tests. No Firebase required.
class FakeAuthService implements AuthService {
  final _controller = StreamController<AuthIdentity?>.broadcast();
  AuthIdentity? _current;

  /// Failure to throw from the next [signIn] call, if set.
  AuthFailure? signInError;

  /// Failure to throw from the next [sendPasswordResetEmail] call, if set.
  AuthFailure? resetError;

  /// When set, [signIn] awaits this before completing (to test loading state).
  Completer<void>? signInGate;

  @override
  Stream<AuthIdentity?> authStateChanges() => _controller.stream;

  @override
  AuthIdentity? get currentIdentity => _current;

  @override
  Future<AuthIdentity> signIn({
    required String email,
    required String password,
  }) async {
    if (signInGate != null) await signInGate!.future;
    if (signInError != null) throw AuthException(signInError!);
    final identity = AuthIdentity(uid: 'uid-$email', email: email);
    _current = identity;
    _controller.add(identity);
    return identity;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (resetError != null) throw AuthException(resetError!);
  }

  /// Test helper: simulate the auth-state stream firing (session restore etc.).
  void emit(AuthIdentity? identity) {
    _current = identity;
    _controller.add(identity);
  }

  void dispose() => _controller.close();
}

/// In-memory [UserRepository] for unit tests.
class FakeUserRepository implements UserRepository {
  final Map<String, ProfileResult> profiles = {};
  bool throwError = false;

  @override
  Future<ProfileResult> getUserProfile(String uid) async {
    if (throwError) throw Exception('firestore unavailable');
    return profiles[uid] ??
        const ProfileResult.problem(ProfileIssue.missing);
  }
}

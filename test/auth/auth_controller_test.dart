import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/auth/application/auth_controller.dart';
import 'package:wildlife_conservation_system/features/auth/data/auth_service.dart';
import 'package:wildlife_conservation_system/features/auth/data/user_repository.dart';
import 'package:wildlife_conservation_system/features/auth/domain/auth_failure.dart';
import 'package:wildlife_conservation_system/features/auth/domain/auth_session.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';
import 'package:wildlife_conservation_system/shared/session/current_user.dart';

import 'fakes.dart';

const _rangerProfile = ProfileResult.ok(AppUser(
  id: 'uid-ranger1@wildguard.lk',
  name: 'K. Perera',
  email: 'ranger1@wildguard.lk',
  role: UserRole.ranger,
  parkId: 'PARK-MIN',
));

ProviderContainer _container(FakeAuthService auth, FakeUserRepository repo) {
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(auth.dispose);
  // Instantiate the controller (subscribes to the auth stream).
  container.read(authControllerProvider);
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('AuthController', () {
    test('1. successful login authenticates and sets the current user', () async {
      final auth = FakeAuthService();
      final repo = FakeUserRepository()
        ..profiles['uid-ranger1@wildguard.lk'] = _rangerProfile;
      final container = _container(auth, repo);

      final failure = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'ranger1@wildguard.lk', password: 'secret');

      expect(failure, isNull);
      final session = container.read(authControllerProvider);
      expect(session, isA<Authenticated>());
      expect((session as Authenticated).user.role, UserRole.ranger);
      expect(container.read(currentUserProvider).email, 'ranger1@wildguard.lk');
    });

    test('1b. username login resolves to the account email and authenticates',
        () async {
      final auth = FakeAuthService();
      final repo = FakeUserRepository()
        ..profiles['uid-ranger1@wildguard.lk'] = _rangerProfile
        ..emailsByUsername['ranger_kumar_001'] = 'ranger1@wildguard.lk';
      final container = _container(auth, repo);

      final failure = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'ranger_kumar_001', password: 'secret');

      expect(failure, isNull);
      expect(container.read(authControllerProvider), isA<Authenticated>());
      expect(container.read(currentUserProvider).email, 'ranger1@wildguard.lk');
    });

    test('1c. unknown username is rejected as invalid credentials', () async {
      final auth = FakeAuthService();
      final container = _container(auth, FakeUserRepository());

      final failure = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'ranger_ghost_001', password: 'secret');

      expect(failure, AuthFailure.invalidCredentials);
      expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('2. invalid credentials surface a friendly failure', () async {
      final auth = FakeAuthService()..signInError = AuthFailure.invalidCredentials;
      final container = _container(auth, FakeUserRepository());

      final failure = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'x@y.lk', password: 'bad');

      expect(failure, AuthFailure.invalidCredentials);
      expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('3. network failure during sign-in is reported', () async {
      final auth = FakeAuthService()..signInError = AuthFailure.network;
      final container = _container(auth, FakeUserRepository());

      final failure = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'x@y.lk', password: 'p');

      expect(failure, AuthFailure.network);
    });

    test('4. logout clears the session', () async {
      final auth = FakeAuthService();
      final repo = FakeUserRepository()
        ..profiles['uid-ranger1@wildguard.lk'] = _rangerProfile;
      final container = _container(auth, repo);

      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'ranger1@wildguard.lk', password: 'secret');
      await container.read(authControllerProvider.notifier).signOut();

      expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('5. password reset request succeeds / maps errors', () async {
      final auth = FakeAuthService();
      final container = _container(auth, FakeUserRepository());
      final notifier = container.read(authControllerProvider.notifier);

      expect(await notifier.sendPasswordReset('a@b.lk'), isNull);

      auth.resetError = AuthFailure.invalidEmail;
      expect(await notifier.sendPasswordReset('bad'), AuthFailure.invalidEmail);
    });

    test('6. auth-state changes drive sign-out', () async {
      final auth = FakeAuthService();
      final repo = FakeUserRepository()
        ..profiles['uid-ranger1@wildguard.lk'] = _rangerProfile;
      final container = _container(auth, repo);

      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'ranger1@wildguard.lk', password: 'secret');
      expect(container.read(authControllerProvider), isA<Authenticated>());

      auth.emit(null); // external sign-out
      await _settle();
      expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('7. session restore loads the profile from a stream event', () async {
      final auth = FakeAuthService();
      final repo = FakeUserRepository()
        ..profiles['uid-ranger1@wildguard.lk'] = _rangerProfile;
      final container = _container(auth, repo);

      expect(container.read(authControllerProvider), isA<AuthInitial>());
      auth.emit(const AuthIdentity(
          uid: 'uid-ranger1@wildguard.lk', email: 'ranger1@wildguard.lk'));
      await _settle();

      expect(container.read(authControllerProvider), isA<Authenticated>());
    });

    test('8. missing Firestore profile routes to Account Issue', () async {
      final auth = FakeAuthService();
      final repo = FakeUserRepository(); // no profile stored
      final container = _container(auth, repo);

      final failure = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'ghost@wildguard.lk', password: 'p');

      expect(failure, AuthFailure.profileMissing);
      final session = container.read(authControllerProvider);
      expect(session, isA<AuthProfileError>());
      expect((session as AuthProfileError).issue, ProfileIssue.missing);
    });

    test('9. disabled profile is rejected', () async {
      final auth = FakeAuthService();
      final repo = FakeUserRepository()
        ..profiles['uid-off@wildguard.lk'] =
            const ProfileResult.problem(ProfileIssue.inactive);
      final container = _container(auth, repo);

      final failure = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'off@wildguard.lk', password: 'p');

      expect(failure, AuthFailure.profileInactive);
      expect((container.read(authControllerProvider) as AuthProfileError).issue,
          ProfileIssue.inactive);
    });

    test('10. unsupported role is rejected', () async {
      final auth = FakeAuthService();
      final repo = FakeUserRepository()
        ..profiles['uid-role@wildguard.lk'] =
            const ProfileResult.problem(ProfileIssue.unsupportedRole);
      final container = _container(auth, repo);

      final failure = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'role@wildguard.lk', password: 'p');

      expect(failure, AuthFailure.unsupportedRole);
    });

    test('offline/demo mode (no Firebase) authenticates a demo user', () {
      // No overrides → authServiceProvider is null (Firebase not configured).
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(authControllerProvider), isA<Authenticated>());
    });
  });

  group('validateProfile', () {
    test('valid document → ok with uid as id', () {
      final result = validateProfile('abc123', {
        'name': 'K. Perera',
        'email': 'ranger1@wildguard.lk',
        'role': 'ranger',
        'parkId': 'PARK-MIN',
        'isActive': true,
      });
      expect(result.isOk, isTrue);
      expect(result.user!.id, 'abc123'); // uid wins over any stored id
    });

    test('unsupported role → problem', () {
      final result = validateProfile('abc', {
        'name': 'X',
        'role': 'superAdmin',
        'parkId': 'PARK-MIN',
      });
      expect(result.issue, ProfileIssue.unsupportedRole);
    });

    test('inactive account → problem', () {
      final result = validateProfile('abc', {
        'name': 'X',
        'role': 'ranger',
        'parkId': 'PARK-MIN',
        'isActive': false,
      });
      expect(result.issue, ProfileIssue.inactive);
    });

    test('incomplete document → problem', () {
      final result = validateProfile('abc', {
        'role': 'ranger',
        'parkId': '',
      });
      expect(result.issue, ProfileIssue.incomplete);
    });

    test('operational role without a park is incomplete', () {
      final result = validateProfile('abc', {
        'name': 'K. Perera',
        'role': 'ranger',
        'parkId': '',
      });
      expect(result.issue, ProfileIssue.incomplete);
    });

    test('admin is valid without a park (not tied to one park)', () {
      final result = validateProfile('admin-uid', {
        'name': 'System Administrator',
        'role': 'admin',
        'parkId': '',
      });
      expect(result.isOk, isTrue);
      expect(result.user!.role, UserRole.admin);
      expect(result.user!.id, 'admin-uid');
    });
  });

  group('AuthFailure.fromFirebaseAuthCode', () {
    test('maps common codes to friendly failures', () {
      expect(AuthFailure.fromFirebaseAuthCode('invalid-credential'),
          AuthFailure.invalidCredentials);
      expect(AuthFailure.fromFirebaseAuthCode('user-disabled'),
          AuthFailure.userDisabled);
      expect(AuthFailure.fromFirebaseAuthCode('network-request-failed'),
          AuthFailure.network);
      expect(AuthFailure.fromFirebaseAuthCode('too-many-requests'),
          AuthFailure.tooManyRequests);
      expect(AuthFailure.fromFirebaseAuthCode('something-new'),
          AuthFailure.unknown);
    });
  });
}

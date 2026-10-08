import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/auth/application/auth_controller.dart';
import 'package:wildlife_conservation_system/features/auth/domain/auth_failure.dart';
import 'package:wildlife_conservation_system/features/auth/presentation/screens/access_denied_screen.dart';
import 'package:wildlife_conservation_system/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:wildlife_conservation_system/features/auth/presentation/screens/login_screen.dart';
import 'package:wildlife_conservation_system/features/auth/presentation/screens/profile_screen.dart';
import 'package:wildlife_conservation_system/features/onboarding/presentation/screens/splash_screen.dart';

import 'fakes.dart';

Widget _wrap(Widget child) {
  return ProviderScope(child: MaterialApp(home: child));
}

/// The login/profile screens are designed to fill a phone-sized viewport
/// without scrolling. Give widget tests a realistic phone surface so the
/// single-screen layout fits (the default 800x600 test window is too short).
void _usePhoneSurface(WidgetTester tester) {
  // Tall phone-sized surface (~400 x 1100 logical) so the single-screen login
  // layout fits with room to spare — test fonts render slightly taller than on
  // device, so we leave generous vertical headroom.
  tester.view.physicalSize = const Size(1200, 3300);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

TextField _passwordField(WidgetTester tester) {
  return tester.widget<TextField>(
    find.descendant(
      of: find.byType(TextFormField).at(1),
      matching: find.byType(TextField),
    ),
  );
}

void main() {
  testWidgets('20. Splash screen renders branding and loading text',
      (tester) async {
    await tester.pumpWidget(_wrap(const SplashScreen()));
    expect(find.text('WILDGUARD'), findsOneWidget);
    expect(find.text('Loading your account…'), findsOneWidget);
  });

  testWidgets('21. Login form renders its fields and actions', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_wrap(const LoginScreen()));
    expect(find.text('WILDGUARD'), findsOneWidget);
    expect(find.text('Email or Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    // No self-registration / social login.
    expect(find.textContaining('Sign Up'), findsNothing);
    expect(find.textContaining('Google'), findsNothing);
  });

  testWidgets('22. invalid email shows a validation error', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_wrap(const LoginScreen()));
    // Contains '@' so it is treated as an email and must be well-formed.
    await tester.enterText(find.byType(TextFormField).first, 'bad@');
    await tester.tap(find.text('SIGN IN'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('23. empty password shows a validation error', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.enterText(
        find.byType(TextFormField).first, 'ranger1@wildguard.lk');
    await tester.tap(find.text('SIGN IN'));
    await tester.pump();
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('24. password visibility toggle flips obscureText',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_wrap(const LoginScreen()));
    expect(_passwordField(tester).obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(_passwordField(tester).obscureText, isFalse);
  });

  testWidgets('25. login shows a loading indicator while signing in',
      (tester) async {
    _usePhoneSurface(tester);
    final auth = FakeAuthService()..signInGate = Completer<void>();
    addTearDown(auth.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: LoginScreen()),
    ));

    await tester.enterText(
        find.byType(TextFormField).first, 'ranger1@wildguard.lk');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('SIGN IN'));
    await tester.pump(); // start async, show spinner

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    auth.signInGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('26. login shows a friendly error message', (tester) async {
    _usePhoneSurface(tester);
    final auth = FakeAuthService()..signInError = AuthFailure.invalidCredentials;
    addTearDown(auth.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: LoginScreen()),
    ));

    await tester.enterText(
        find.byType(TextFormField).first, 'ranger1@wildguard.lk');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('27. forgot password form renders and confirms on success',
      (tester) async {
    final auth = FakeAuthService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: ForgotPasswordScreen()),
    ));

    expect(find.text('Send Reset Link'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).first, 'ranger1@wildguard.lk');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();

    expect(
      find.text('Password reset instructions have been sent to your email.'),
      findsOneWidget,
    );
  });

  testWidgets('28. access denied screen renders', (tester) async {
    await tester.pumpWidget(_wrap(const AccessDeniedScreen()));
    await tester.pump();
    expect(find.text('Access Denied'), findsOneWidget);
    expect(
      find.text('You do not have permission to access this section.'),
      findsOneWidget,
    );
  });

  testWidgets('29. profile renders the current user info', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_wrap(const ProfileScreen()));
    await tester.pump();
    // Offline/demo mode → the default demo session user is the Park Manager.
    expect(find.text('Park Manager'), findsWidgets);
    expect(find.text('manager@wildguard.lk'), findsOneWidget);
    // Sign Out sits at the bottom of the scrollable profile.
    await tester.scrollUntilVisible(find.text('Sign Out'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets('30. logout confirmation dialog appears', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_wrap(const ProfileScreen()));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Sign Out'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out of WildGuard?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    // Dismiss to avoid triggering sign-out side effects.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}

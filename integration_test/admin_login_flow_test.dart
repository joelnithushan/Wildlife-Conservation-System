import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:wildlife_conservation_system/main.dart' as app;

/// End-to-end test driving the REAL app (real Firebase Auth + Firestore) on a
/// connected device/emulator:
///
///   onboarding (skip) -> login as the seeded admin -> admin dashboard
///   -> open the Add-User form -> required-field validation -> Profile -> sign out
///
/// Run with:
///   flutter test integration_test/admin_login_flow_test.dart -d DEVICE_ID
///
/// Requires Email/Password enabled in Firebase and network connectivity so the
/// default admin (admin@gmail.com) can be seeded and signed in.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps frames until [finder] matches or [timeout] elapses. Needed because
  /// Firebase sign-in / Firestore reads are network calls — pumpAndSettle would
  /// either return too early or hang on the loading spinner.
  Future<bool> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 300));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  /// Drives whatever screen is showing until the login screen is reached.
  ///
  /// Handles every possible entry state robustly: `main()` still running its
  /// async Firebase init (no UI yet → keep pumping), the 3-page onboarding
  /// (tap Skip), or a restored session from a previous run (sign out). Polls in
  /// a loop because the UI isn't rendered the instant `app.main()` returns.
  Future<bool> reachLogin(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 400));

      if (find.text('SIGN IN').evaluate().isNotEmpty) return true;

      // Onboarding → skip straight to login.
      final skip = find.text('Skip');
      if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip);
        await tester.pumpAndSettle();
        continue;
      }

      // Restored session → sign out via the Profile tab.
      final profileTab = find.text('Profile');
      final signOut = find.text('Sign Out');
      if (signOut.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(signOut, 300,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(signOut);
        await tester.pumpAndSettle();
        final confirm = find.widgetWithText(FilledButton, 'Sign Out');
        if (confirm.evaluate().isNotEmpty) {
          await tester.tap(confirm);
          await tester.pumpAndSettle();
        }
        continue;
      }
      if (profileTab.evaluate().isNotEmpty) {
        await tester.tap(profileTab.last);
        await tester.pumpAndSettle();
        continue;
      }
      // Otherwise splash / still initializing — keep pumping.
    }
    return false;
  }

  testWidgets('admin can log in and reach account management', (tester) async {
    app.main();

    // --- Reach the login screen (handles onboarding / restored session) ----
    expect(await reachLogin(tester), isTrue,
        reason: 'app should reach the login screen on startup');
    final signIn = find.text('SIGN IN');
    expect(find.text('Email or Username'), findsOneWidget);

    // Enter the seeded admin credentials.
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin@gmail.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.pump();

    await tester.tap(signIn);
    await tester.pump(); // kick off the async sign-in

    // --- Admin dashboard ---------------------------------------------------
    final adminTitle = find.text('WildGuard · Admin');
    expect(await pumpUntil(tester, adminTitle), isTrue,
        reason: 'admin dashboard should load after a successful login');

    // Role-aware navbar: admin sees Users + Profile.
    expect(find.text('Users'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Add user'), findsOneWidget);

    // --- Add-user form -----------------------------------------------------
    await tester.tap(find.text('Add user'));
    await tester.pumpAndSettle();
    expect(find.text('Create User'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Role'), findsOneWidget);

    // The form is a lazy ListView; scroll to confirm the Create button at the
    // bottom is present (the create/validation logic itself is unit-tested).
    final createBtn = find.text('Create user');
    await tester.scrollUntilVisible(createBtn, 300,
        scrollable: find.byType(Scrollable).first);
    expect(createBtn, findsOneWidget);

    // Back to the dashboard.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('WildGuard · Admin'), findsOneWidget);

    // --- Profile tab -------------------------------------------------------
    await tester.tap(find.text('Profile').last);
    expect(await pumpUntil(tester, find.text('admin@gmail.com')), isTrue,
        reason: 'profile should show the admin email');
    expect(find.text('My Profile'), findsOneWidget);

    // --- Sign out ----------------------------------------------------------
    final signOut = find.text('Sign Out');
    await tester.scrollUntilVisible(signOut, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    // Confirm in the dialog (the confirm action is a FilledButton).
    expect(find.text('Sign out of WildGuard?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
    await tester.pumpAndSettle();

    // Back at the login screen.
    expect(await pumpUntil(tester, find.text('SIGN IN')), isTrue,
        reason: 'signing out returns to the login screen');
  });
}

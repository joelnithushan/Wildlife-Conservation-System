import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:wildlife_conservation_system/main.dart' as app;

/// Logs in as each seeded role and verifies the correct dashboard loads.
///
/// Assumes the demo staff have been seeded (admin → "Load demo staff") and that
/// Email/Password is enabled. Run with:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/role_dashboards_test.dart --no-dds -d DEVICE
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<bool> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 350));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  /// Drives whatever screen is showing to the login screen (handles startup,
  /// onboarding and a restored session).
  Future<bool> reachLogin(WidgetTester tester,
      {Duration timeout = const Duration(seconds: 45)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 400));
      if (find.text('SIGN IN').evaluate().isNotEmpty) return true;

      final skip = find.text('Skip');
      if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip);
        await tester.pumpAndSettle();
        continue;
      }

      // On the profile screen: scroll to and tap Sign Out, then confirm.
      final signOut = find.widgetWithText(OutlinedButton, 'Sign Out');
      if (signOut.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(signOut, 250,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(signOut);
        await tester.pumpAndSettle();
        final confirm = find.widgetWithText(FilledButton, 'Sign Out');
        if (await pumpUntil(tester, confirm,
            timeout: const Duration(seconds: 5))) {
          await tester.tap(confirm);
          await tester.pumpAndSettle();
        }
        // Wait for the sign-out redirect back to login.
        await pumpUntil(tester, find.text('SIGN IN'),
            timeout: const Duration(seconds: 10));
        continue;
      }
      // On a dashboard: open the Profile tab to reach the Sign Out button.
      final profileTab = find.text('Profile');
      if (profileTab.evaluate().isNotEmpty) {
        await tester.tap(profileTab.last);
        await tester.pumpAndSettle();
        continue;
      }
    }
    return false;
  }

  Future<void> loginAndCheck(
    WidgetTester tester, {
    required String identifier,
    required String password,
    required String expectDashboardText,
  }) async {
    expect(await reachLogin(tester), isTrue,
        reason: 'should reach login before signing in as $identifier');

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), identifier);
    await tester.enterText(fields.at(1), password);
    await tester.pump();
    await tester.tap(find.text('SIGN IN'));
    await tester.pump();

    expect(await pumpUntil(tester, find.text(expectDashboardText)), isTrue,
        reason: '$identifier should land on a dashboard showing '
            '"$expectDashboardText"');
  }

  testWidgets('each role lands on its own dashboard', (tester) async {
    app.main();

    // Admin first (seeded by default); verify the admin console.
    await loginAndCheck(tester,
        identifier: 'admin@gmail.com',
        password: 'password123',
        expectDashboardText: 'WildGuard · Admin');

    // Park Manager — by username.
    await loginAndCheck(tester,
        identifier: 'manager_sunil_001',
        password: 'password123',
        expectDashboardText: 'Park Manager');

    // Ranger — by email.
    await loginAndCheck(tester,
        identifier: 'ranger1@wildguard.lk',
        password: 'password123',
        expectDashboardText: 'Ranger');

    // Community Liaison Officer — by username.
    await loginAndCheck(tester,
        identifier: 'clo_nimal_001',
        password: 'password123',
        expectDashboardText: 'Community Liaison Officer');

    // Conservation Researcher — by email.
    await loginAndCheck(tester,
        identifier: 'researcher@wildguard.lk',
        password: 'password123',
        expectDashboardText: 'Conservation Researcher');
  });
}

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildlife_conservation_system/app.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';

void main() {
  testWidgets(
      'App boots through splash to the role dashboard (offline demo mode)',
      (tester) async {
    SharedPreferences.setMockInitialValues({'flutter.onboarding_completed': true});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider
              .overrideWith((ref) => AppDatabase(NativeDatabase.memory())),
        ],
        child: const WildlifeApp(),
      ),
    );

    // Firebase is not configured in tests, so the app runs in offline/demo mode
    // and lands on the Park Manager dashboard for the demo session user.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('WildGuard'), findsOneWidget);
    expect(find.text('Patrol Operations'), findsOneWidget);
    expect(find.text('Conservation Reports'), findsOneWidget);
  });
}

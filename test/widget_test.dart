import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/app.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';

void main() {
  testWidgets('App boots to the dashboard with bottom navigation',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider
              .overrideWith((ref) => AppDatabase(NativeDatabase.memory())),
        ],
        child: const WildlifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    // Lands on the patrol tab (My Patrols) with the 4-module bottom nav.
    expect(find.text('My Patrols'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Patrol'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
  });
}

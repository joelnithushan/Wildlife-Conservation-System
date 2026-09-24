import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/screens/assign_patrol_route_screen.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/screens/my_patrols_screen.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/widgets/status_banners.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget wrap(Widget child) => ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) => db)],
        child: MaterialApp(home: child),
      );

  testWidgets('My Patrols shows empty state and Assign FAB for manager',
      (tester) async {
    await tester.pumpWidget(wrap(const MyPatrolsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('My Patrols'), findsOneWidget);
    expect(find.textContaining('No patrols'), findsOneWidget);
    expect(find.text('Assign Patrol'), findsOneWidget); // manager default role
  });

  testWidgets('Assign screen validates missing route selection', (tester) async {
    await tester.pumpWidget(wrap(const AssignPatrolRouteScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Assign Patrol Route'), findsOneWidget);
    // Routes from demo data are listed.
    expect(find.textContaining('North Ridge'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Assign Patrol'));
    await tester.pump(); // show snackbar

    expect(find.text('Please select a patrol route.'), findsOneWidget);
  });

  testWidgets('OfflineBanner renders offline message with pending count',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: OfflineBanner(pendingCount: 7)),
    ));
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.textContaining('7 record(s) pending'), findsOneWidget);
  });

  testWidgets('SyncBanner shows synchronizing state', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SyncBanner(message: 'Synchronizing…', isSyncing: true)),
    ));
    expect(find.textContaining('Back online'), findsOneWidget);
  });
}

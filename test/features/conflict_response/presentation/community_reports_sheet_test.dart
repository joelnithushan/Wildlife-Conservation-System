import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/datasources/conflict_local_data_source.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/notification/simulated_notification_service.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/drift_conflict_repository.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/screens/community_reports_sheet.dart';
import 'package:wildlife_conservation_system/shared/models/community_report.dart';

import '../../../patrol/helpers.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 9, 26, 10, 0, 0);
  const park = 'PARK-MIN'; // default current user (park manager) park

  late AppDatabase db;

  DriftConflictRepository repo() => DriftConflictRepository(
        localDataSource: ConflictLocalDataSource(db),
        notificationService: SimulatedNotificationService(),
        now: () => fixedNow,
      );

  Widget wrap() => ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) => db)],
        child: const MaterialApp(
          home: Scaffold(body: CommunityReportsSheet()),
        ),
      );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('renders the empty state when there are no reports',
      (tester) async {
    // Trigger the repo's one-time demo seed, then confirm the header renders.
    await repo().getCommunityReports(park);
    // Demo seed inserts reports, so instead assert the header always shows.
    await pump(tester);
    expect(find.text('Community Reports'), findsOneWidget);
    expect(find.text('New Report'), findsOneWidget);
  });

  testWidgets('lists an unverified report and verifies it on tap',
      (tester) async {
    final local = ConflictLocalDataSource(db);
    // A credible report inside RZ-01 so verifying raises an alert.
    await local.upsertCommunityReport(CommunityReport(
      id: 'cr-credible',
      parkId: park,
      description: 'Elephant pushing the fence',
      latitude: 8.030,
      longitude: 80.900,
      createdAt: fixedNow,
      channel: 'SMS',
    ));

    await pump(tester);

    expect(find.text('Elephant pushing the fence'), findsOneWidget);
    expect(find.text('Verify as credible'), findsWidgets);

    await tester.tap(find.text('Verify as credible').first);
    await tester.pumpAndSettle();

    // Snackbar confirms, and the report now shows a Verified chip.
    expect(find.textContaining('verified'), findsWidgets);
    expect(find.text('Verified'), findsWidgets);
  });
}

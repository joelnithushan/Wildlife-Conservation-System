import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/incidents/data/datasources/incident_local_data_source.dart';
import 'package:wildlife_conservation_system/shared/models/incident_report.dart';

import '../helpers.dart';

void main() {
  Future<void> seed(AppDatabase db, IncidentReport report) =>
      IncidentLocalDataSource(db).upsertIncident(report);

  IncidentReport report({
    required String id,
    required SyncState syncState,
    IncidentCategory category = IncidentCategory.poaching,
  }) =>
      IncidentReport(
        id: id,
        rangerId: 'R001',
        parkId: 'PARK-MIN',
        category: category,
        description: 'Wire snare near the river crossing',
        observedAt: DateTime.utc(2026, 9, 23, 7, 14),
        latitude: 8.03,
        longitude: 80.89,
        locationSource: LocationSource.gps,
        localPhotoPath: '/tmp/evidence.jpg',
        submissionStatus: SubmissionStatus.submitted,
        reviewStatus: ReviewStatus.pendingReview,
        syncState: syncState,
        createdAt: DateTime.utc(2026, 9, 23, 7, 20),
      );

  testWidgets('lists synchronized and pending reports with status',
      (tester) async {
    final db = createIncidentTestDatabase();
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
    ]);
    addTearDown(c.dispose);
    c.read(currentUserProvider.notifier).signIn(DemoData.parkManager);
    await seed(db, report(id: 'i_synced', syncState: SyncState.synchronized));
    await seed(
      db,
      report(
        id: 'i_pending',
        syncState: SyncState.pending,
        category: IncidentCategory.animalInjury,
      ),
    );

    await pumpUc02Screen(
      tester,
      const SizedBox.shrink(),
      container: c,
      initialLocation: AppRoutes.incidents,
    );

    expect(find.text('Snare'), findsOneWidget);
    expect(find.text('Carcass'), findsOneWidget);
    expect(find.text('Reports pending sync on this device: 1'), findsOneWidget);
    expect(find.text('Submission: Submitted'), findsNWidgets(2));
    expect(find.text('Pending review'), findsWidgets);
    expect(find.text('Incident Review'), findsOneWidget);
  });

  testWidgets('switching to Ranger hides the manager review entry',
      (tester) async {
    final db = createIncidentTestDatabase();
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
    ]);
    addTearDown(c.dispose);
    c.read(currentUserProvider.notifier).signIn(DemoData.parkManager);

    await pumpUc02Screen(
      tester,
      const SizedBox.shrink(),
      container: c,
      initialLocation: AppRoutes.incidents,
    );

    await tester.tap(find.byTooltip('Switch demo role'));
    await tester.pumpAndSettle();
    expect(find.text('Ranger'), findsWidgets);
    expect(find.text('Park Manager'), findsWidgets);
    c.read(currentUserProvider.notifier).switchRole(UserRole.ranger);
    await tester.pumpAndSettle();

    expect(find.text('Incident Review'), findsNothing);
    expect(c.read(currentUserProvider).role, UserRole.ranger);
  });
}

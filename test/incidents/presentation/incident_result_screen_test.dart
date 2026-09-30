import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/incidents/data/datasources/incident_local_data_source.dart';
import 'package:wildlife_conservation_system/shared/models/incident_report.dart';

import '../helpers.dart';

void main() {
  // UC02 Screens 5 & 6 – Submission result (offline saved / synchronized).
  // Seed a report the screen will show.
  Future<void> seed(
    AppDatabase db,
    String id,
    SyncState syncState,
  ) async {
    await IncidentLocalDataSource(db).upsertIncident(
      IncidentReport(
        id: id,
        rangerId: 'R001',
        parkId: 'PARK-MIN',
        category: IncidentCategory.poaching,
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
      ),
    );
  }

  testWidgets('offline-saved report shows the offline banner and retry',
      (tester) async {
    final db = createIncidentTestDatabase();
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      connectivityServiceProvider
          .overrideWithValue(FakeConnectivityService(online: false)),
      syncServiceProvider.overrideWithValue(FakeSyncService()),
    ]);
    addTearDown(c.dispose);
    c.read(currentUserProvider.notifier).signIn(DemoData.rangerPerera);

    const id = 'incident_result_offline';
    await seed(db, id, SyncState.pending);

    await pumpUc02Screen(
      tester,
      const SizedBox.shrink(),
      container: c,
      initialLocation: AppRoutes.incidentResultFor(id),
    );
    await tester.pumpAndSettle();

    expect(find.text('Report submitted'), findsOneWidget);
    // The submission provider is fresh here, so the reference falls back to
    // the stable report ID (the wizard flow shows the IR- short form).
    expect(find.textContaining('Reference: '), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget); // sync status chip
    expect(find.text('Pending review'), findsOneWidget); // review status chip
    expect(find.textContaining('Offline – saved on this device.'),
        findsOneWidget);
    // The banner text and the caption both mention automatic synchronization.
    expect(
        find.textContaining('synchronize automatically'), findsExactly(2));
    expect(find.text('Retry sync now'), findsOneWidget);
  });

  testWidgets('synchronized report shows Synchronized and no retry action',
      (tester) async {
    final db = createIncidentTestDatabase();
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      connectivityServiceProvider
          .overrideWithValue(FakeConnectivityService(online: true)),
      syncServiceProvider.overrideWithValue(FakeSyncService()),
    ]);
    addTearDown(c.dispose);
    c.read(currentUserProvider.notifier).signIn(DemoData.rangerPerera);

    const id = 'incident_result_synced';
    await seed(db, id, SyncState.synchronized);

    await pumpUc02Screen(
      tester,
      const SizedBox.shrink(),
      container: c,
      initialLocation: AppRoutes.incidentResultFor(id),
    );
    await tester.pumpAndSettle();

    expect(find.text('Report submitted'), findsOneWidget);
    expect(find.text('Synchronized'), findsOneWidget);
    expect(find.text('Retry sync now'), findsNothing);
    expect(find.textContaining('Offline – saved on this device.'),
        findsNothing);
  });
}

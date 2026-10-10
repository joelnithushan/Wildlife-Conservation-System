import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/incidents/data/datasources/incident_local_data_source.dart';
import 'package:wildlife_conservation_system/shared/models/incident_report.dart';

import '../helpers.dart';

void main() {
  // UC02 Screen 8 – Review one report (Park Manager).
  Future<ProviderContainer> seededContainer(
    WidgetTester tester, {
    ReviewStatus reviewStatus = ReviewStatus.pendingReview,
    String? omissionReason,
  }) async {
    final db = createIncidentTestDatabase();
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
    ]);
    addTearDown(c.dispose);
    c.read(currentUserProvider.notifier).signIn(DemoData.parkManager);

    await IncidentLocalDataSource(db).upsertIncident(
      IncidentReport(
        id: 'i_detail',
        rangerId: 'R001',
        parkId: 'PARK-MIN',
        category: IncidentCategory.snare,
        description: 'Wire snare near the river crossing',
        observedAt: DateTime.utc(2026, 9, 23, 7, 14),
        latitude: 8.03,
        longitude: 80.89,
        locationSource: LocationSource.gps,
        localPhotoPath: omissionReason == null ? '/tmp/evidence.jpg' : null,
        evidenceOmissionReason: omissionReason,
        submissionStatus: SubmissionStatus.submitted,
        reviewStatus: reviewStatus,
        syncState: SyncState.synchronized,
        createdAt: DateTime.utc(2026, 9, 23, 7, 20),
      ),
    );

    await pumpUc02Screen(
      tester,
      const SizedBox.shrink(),
      container: c,
      initialLocation: AppRoutes.incidentReviewDetailFor('i_detail'),
    );
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('shows report details, omission reason and decision controls',
      (tester) async {
    await seededContainer(
      tester,
      omissionReason: 'Unsafe to approach the snare location.',
    );

    expect(find.text('Review Incident'), findsOneWidget);
    expect(find.textContaining('i_detail'), findsOneWidget);
    expect(find.text('snare'), findsOneWidget);
    expect(find.text('R001'), findsOneWidget);
    expect(find.text('GPS'), findsOneWidget);
    expect(find.text('Wire snare near the river crossing'), findsOneWidget);
    expect(find.textContaining('Unsafe to approach'), findsExactly(2));
    expect(find.text('Under review'), findsAtLeastNWidgets(1)); // default selection
    expect(find.byKey(const Key('review-note-field')), findsOneWidget);
    expect(find.text('Save Review'), findsOneWidget);
  });

  testWidgets('reviewer verifies an incident with a note and status is stored',
      (tester) async {
    final c = await seededContainer(tester);
    final db = c.read(appDatabaseProvider);

    await tester.tap(find.text('Verified'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('review-note-field')),
      'Site inspected, snare removed.',
    );
    await tester.pump();
    await tester.tap(find.text('Save Review'));
    await tester.pumpAndSettle();

    // The controller pops back to the queue root on success.
    final stored = await IncidentLocalDataSource(db).getIncidentById('i_detail');
    expect(stored!.reviewStatus, ReviewStatus.verified);
    expect(stored.reviewerId, 'PM001');
    expect(stored.reviewNotes, 'Site inspected, snare removed.');
    expect(stored.reviewedAt, isNotNull);
  });

  testWidgets('reviewer can set Under review then Rejected', (tester) async {
    final c = await seededContainer(tester);
    final db = c.read(appDatabaseProvider);

    await tester.tap(find.text('Under review'));
    await tester.pump();
    await tester.tap(find.text('Save Review'));
    await tester.pumpAndSettle();
    var stored = await IncidentLocalDataSource(db).getIncidentById('i_detail');
    expect(stored!.reviewStatus, ReviewStatus.underReview);
    expect(find.text('Review saved: underReview.'), findsOneWidget);

    // Re-open and reject.
    await pumpUc02Screen(
      tester,
      const SizedBox.shrink(),
      container: c,
      initialLocation: AppRoutes.incidentReviewDetailFor('i_detail'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rejected'));
    await tester.pump();
    await tester.tap(find.text('Save Review'));
    await tester.pumpAndSettle();

    stored = await IncidentLocalDataSource(db).getIncidentById('i_detail');
    expect(stored!.reviewStatus, ReviewStatus.rejected);
  });

  testWidgets('optional note can be left empty', (tester) async {
    final c = await seededContainer(tester);
    final db = c.read(appDatabaseProvider);

    await tester.tap(find.text('Verified'));
    await tester.pump();
    await tester.tap(find.text('Save Review'));
    await tester.pumpAndSettle();

    final stored = await IncidentLocalDataSource(db).getIncidentById('i_detail');
    expect(stored!.reviewStatus, ReviewStatus.verified);
    expect(stored.reviewNotes, isNull);
  });

  testWidgets('non-reviewer is not authorized to save a review',
      (tester) async {
    final db = createIncidentTestDatabase();
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
    ]);
    addTearDown(c.dispose);
    c.read(currentUserProvider.notifier).signIn(DemoData.rangerPerera);

    await IncidentLocalDataSource(db).upsertIncident(
      IncidentReport(
        id: 'i_noauth',
        rangerId: 'R002',
        parkId: 'PARK-MIN',
        category: IncidentCategory.snare,
        description: 'Wire snare near the river crossing',
        observedAt: DateTime.utc(2026, 9, 23, 7, 14),
        latitude: 8.03,
        longitude: 80.89,
        locationSource: LocationSource.gps,
        submissionStatus: SubmissionStatus.submitted,
        reviewStatus: ReviewStatus.pendingReview,
        syncState: SyncState.synchronized,
        createdAt: DateTime.utc(2026, 9, 23, 7, 20),
      ),
    );

    await pumpUc02Screen(
      tester,
      const SizedBox.shrink(),
      container: c,
      initialLocation: AppRoutes.incidentReviewDetailFor('i_noauth'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Review'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not authorized'), findsWidgets);
    final stored =
        await IncidentLocalDataSource(db).getIncidentById('i_noauth');
    expect(stored!.reviewStatus, ReviewStatus.pendingReview); // unchanged
  });
}

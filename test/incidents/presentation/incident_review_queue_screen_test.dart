import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/errors/exceptions.dart';
import 'package:wildlife_conservation_system/features/incidents/data/datasources/incident_local_data_source.dart';
import 'package:wildlife_conservation_system/features/incidents/presentation/screens/incident_review_queue_screen.dart';
import 'package:wildlife_conservation_system/shared/models/incident_report.dart';
import 'package:wildlife_conservation_system/shared/repositories/incident_repository.dart';

import '../helpers.dart';

/// Repository whose queue read always fails (service unavailable).
class _ThrowingRepository implements IncidentRepository {
  @override
  Future<List<IncidentReport>> getIncidentsForReview(String parkId) async {
    throw const LocalStorageException('service down');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const LocalStorageException('service down');
}

void main() {
  // UC02 Screen 7 – Incident Review queue (Park Manager).
  Future<void> seed(
    ProviderContainer c,
    String id, {
    SyncState syncState = SyncState.synchronized,
    ReviewStatus reviewStatus = ReviewStatus.pendingReview,
    String rangerId = 'R001',
    IncidentCategory category = IncidentCategory.snare,
  }) async {
    await IncidentLocalDataSource(
      c.read(appDatabaseProvider),
    ).upsertIncident(
      IncidentReport(
        id: id,
        rangerId: rangerId,
        parkId: 'PARK-MIN',
        category: category,
        description: 'Wire snare near the river crossing',
        observedAt: DateTime.utc(2026, 9, 23, 7, 14),
        latitude: 8.03,
        longitude: 80.89,
        locationSource: LocationSource.gps,
        localPhotoPath: '/tmp/evidence.jpg',
        submissionStatus: SubmissionStatus.submitted,
        reviewStatus: reviewStatus,
        syncState: syncState,
        createdAt: DateTime.utc(2026, 9, 23, 7, 20),
      ),
    );
  }

  ProviderContainer managerContainer({AppDatabase? db, Object? overrideRepository}) {
    final database = db ?? createIncidentTestDatabase();
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => database),
      if (overrideRepository != null)
        incidentRepositoryProvider
            .overrideWithValue(overrideRepository as IncidentRepository),
    ]);
    c.read(currentUserProvider.notifier).signIn(DemoData.parkManager);
    return c;
  }

  testWidgets('shows synchronized pending reports with category, ranger, chip',
      (tester) async {
    final c = managerContainer();
    addTearDown(c.dispose);
    await seed(c, 'i_q1');
    await seed(c, 'i_q2', category: IncidentCategory.carcass);

    await pumpUc02Screen(tester, const IncidentReviewQueueScreen(),
        container: c, initialLocation: AppRoutes.incidentReviewQueue);
    await tester.pumpAndSettle();

    expect(find.text('Incident Review'), findsOneWidget);
    expect(find.text('Pending review'), findsWidgets); // chip filter + status
    expect(find.text('snare'), findsOneWidget);
    expect(find.text('carcass'), findsOneWidget);
    expect(find.textContaining('Ranger: R001'), findsWidgets);
  });

  testWidgets('default filter is Pending review; switching to Verified '
      'hides pending reports', (tester) async {
    final c = managerContainer();
    addTearDown(c.dispose);
    await seed(c, 'i_pending');

    await pumpUc02Screen(tester, const IncidentReviewQueueScreen(),
        container: c, initialLocation: AppRoutes.incidentReviewQueue);
    await tester.pumpAndSettle();

    expect(find.text('snare'), findsOneWidget);

    await tester.tap(find.text('Verified'));
    await tester.pumpAndSettle();

    expect(find.text('snare'), findsNothing);
    expect(find.text('No verified reports yet.'), findsOneWidget);
  });

  testWidgets('unsynchronized ranger reports never enter the queue',
      (tester) async {
    final c = managerContainer();
    addTearDown(c.dispose);
    await seed(c, 'i_local', syncState: SyncState.pending);
    await seed(c, 'i_failed', syncState: SyncState.failed);

    await pumpUc02Screen(tester, const IncidentReviewQueueScreen(),
        container: c, initialLocation: AppRoutes.incidentReviewQueue);
    await tester.pumpAndSettle();

    expect(find.text('No reports waiting for review.'), findsOneWidget);
    expect(find.textContaining('Ranger: R001'), findsNothing);
  });

  testWidgets('empty queue shows the friendly empty state', (tester) async {
    final c = managerContainer();
    addTearDown(c.dispose);

    await pumpUc02Screen(tester, const IncidentReviewQueueScreen(),
        container: c, initialLocation: AppRoutes.incidentReviewQueue);
    await tester.pumpAndSettle();

    expect(find.text('No reports waiting for review.'), findsOneWidget);
    expect(
        find.textContaining("once rangers' devices synchronize"),
        findsOneWidget);
  });

  testWidgets('service error shows the error view with retry', (tester) async {
    // A repository whose queue read always fails (service unavailable).
    final c = managerContainer(
      overrideRepository: _ThrowingRepository(),
    );

    await pumpUc02Screen(tester, const IncidentReviewQueueScreen(),
        container: c, initialLocation: AppRoutes.incidentReviewQueue);
    await tester.pumpAndSettle();

    expect(find.textContaining('The review service is unavailable.'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('opening a report pushes the review detail screen',
      (tester) async {
    final c = managerContainer();
    addTearDown(c.dispose);
    await seed(c, 'i_open');

    await pumpUc02Screen(tester, const IncidentReviewQueueScreen(),
        container: c, initialLocation: AppRoutes.incidentReviewQueue);
    await tester.pumpAndSettle();

    await tester.tap(find.text('snare'));
    await tester.pumpAndSettle();

    expect(find.text('Review Incident'), findsOneWidget);
    expect(find.textContaining('i_open'), findsOneWidget);
  });
}

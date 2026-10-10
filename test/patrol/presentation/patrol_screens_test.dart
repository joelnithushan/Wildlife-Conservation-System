import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/routing/app_router.dart';
import 'package:wildlife_conservation_system/features/patrol/data/datasources/patrol_local_data_source.dart';
import 'package:wildlife_conservation_system/features/patrol/data/repositories/patrol_repository_impl.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/screens/manual_waypoint_screen.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/screens/patrol_details_screen.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/screens/patrol_in_progress_screen.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/screens/patrol_summary_screen.dart';
import 'package:wildlife_conservation_system/shared/models/patrol_position.dart';
import 'package:wildlife_conservation_system/shared/providers/providers.dart';
import 'package:wildlife_conservation_system/shared/services/location_service.dart';

import '../helpers.dart';

/// Fake GPS so the tracking controller never touches the real geolocator.
class _FakeLocation implements LocationService {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<({double latitude, double longitude})> getCurrentPosition() async =>
      (latitude: 8.031, longitude: 80.891);
  @override
  Stream<({double latitude, double longitude})> positionStream() =>
      const Stream.empty();
}

/// GPS that denies permission so the in-progress screen shows its GPS-off card.
class _NoGpsLocation implements LocationService {
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<({double latitude, double longitude})> getCurrentPosition() async =>
      throw StateError('no gps');
  @override
  Stream<({double latitude, double longitude})> positionStream() =>
      const Stream.empty();
}

void main() {
  late AppDatabase db;
  late PatrolRepositoryImpl repo;
  final now = DateTime.utc(2026, 9, 23, 8);

  setUp(() {
    db = createTestDatabase();
    repo = PatrolRepositoryImpl(
      local: PatrolLocalDataSource(db),
      resolveRoute: testRouteResolver, // RT-07 North Ridge (also in DemoData)
      clock: () => now,
    );
  });
  tearDown(() => db.close());

  Future<String> seedAssigned() async {
    final p = await repo.assignRoute(
        routeId: 'RT-07', rangerId: 'R001', parkId: 'PARK-MIN', scheduledFor: now);
    return p.id;
  }

  Future<String> seedInProgress() async {
    final id = await seedAssigned();
    await repo.startPatrol(id);
    await repo.savePosition(PatrolPosition.create(
        patrolId: id, latitude: 8.031, longitude: 80.891, timestamp: now));
    return id;
  }

  Future<String> seedCompleted() async {
    final id = await seedInProgress();
    await repo.completePatrol(id);
    return id;
  }

  // `online: false` keeps the in-progress screen off its 1s `Stream.periodic`
  // "Elapsed" ticker (only built when online), so pumpAndSettle can settle.
  Widget wrap(Widget child, {bool online = true}) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          locationServiceProvider.overrideWithValue(_FakeLocation()),
          isOnlineProvider.overrideWith((ref) => Stream.value(online)),
        ],
        child: MaterialApp(home: child),
      );

  // Phone-sized surface so the long ListView screens don't overflow in tests.
  Future<void> pumpScreen(WidgetTester tester, Widget child,
      {bool online = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(child, online: online));
    await tester.pumpAndSettle();
  }

  group('PatrolDetailsScreen', () {
    testWidgets('shows route, distance, sync state and Start Patrol when assigned',
        (tester) async {
      final id = await seedAssigned();
      await pumpScreen(tester, PatrolDetailsScreen(patrolId: id));

      expect(find.text('Patrol Details'), findsOneWidget);
      expect(find.text('Route ID'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Sync state'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Start Patrol'), findsOneWidget);
    });

    testWidgets('offers Resume (not Start) once the patrol is in progress',
        (tester) async {
      final id = await seedInProgress();
      await pumpScreen(tester, PatrolDetailsScreen(patrolId: id));

      expect(find.widgetWithText(FilledButton, 'Resume Patrol'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Start Patrol'), findsNothing);
    });

    testWidgets('offers View Summary once the patrol is completed',
        (tester) async {
      final id = await seedCompleted();
      await pumpScreen(tester, PatrolDetailsScreen(patrolId: id));

      expect(find.widgetWithText(FilledButton, 'View Summary'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Start Patrol'), findsNothing);
    });

    testWidgets('shows a not-found message for an unknown patrol id',
        (tester) async {
      await pumpScreen(tester, const PatrolDetailsScreen(patrolId: 'nope'));
      expect(find.text('Patrol not found.'), findsOneWidget);
    });
  });

  group('PatrolInProgressScreen', () {
    testWidgets('shows tracking actions, positions and finish control',
        (tester) async {
      final id = await seedInProgress();
      await pumpScreen(tester, PatrolInProgressScreen(patrolId: id),
          online: false);

      expect(find.text('Mark Waypoint (GPS)'), findsOneWidget);
      expect(find.text('Manual Waypoint'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Finish Patrol'), findsOneWidget);
      expect(find.text('Positions'), findsOneWidget); // stat card label
    });

    testWidgets('records a GPS waypoint when Mark Waypoint is tapped',
        (tester) async {
      final id = await seedInProgress();
      await pumpScreen(tester, PatrolInProgressScreen(patrolId: id),
          online: false);

      final before = (await repo.getPositions(id)).length;
      await tester.tap(find.text('Mark Waypoint (GPS)'));
      await tester.pumpAndSettle();

      final after = await repo.getPositions(id);
      expect(after.length, greaterThan(before)); // fake GPS fix persisted
      expect(after.any((p) => p.captureMode.name == 'gps'), isTrue);
    });
  });

  // Router wrapper so screens that navigate (push/pushReplacement) work. Stub
  // destinations stand in for the summary/waypoint/list routes.
  Widget wrapRouter(String id,
      {bool online = true, LocationService? location}) {
    final router = GoRouter(
      initialLocation: AppRoutes.activeFor(id),
      routes: [
        GoRoute(
          path: '/patrol-active/:id',
          builder: (c, s) =>
              PatrolInProgressScreen(patrolId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/patrol-summary/:id',
          builder: (c, s) =>
              const Scaffold(body: Center(child: Text('SUMMARY STUB'))),
        ),
        GoRoute(
          path: '/patrol-waypoint/:id',
          builder: (c, s) =>
              const Scaffold(body: Center(child: Text('WAYPOINT STUB'))),
        ),
        GoRoute(
          path: '/patrol',
          builder: (c, s) =>
              const Scaffold(body: Center(child: Text('PATROL LIST STUB'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        locationServiceProvider
            .overrideWithValue(location ?? _FakeLocation()),
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('PatrolInProgressScreen – finish flow', () {
    testWidgets('finishing the patrol completes it and navigates to the summary',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final id = await seedInProgress();
      await tester.pumpWidget(wrapRouter(id, online: false));
      await tester.pumpAndSettle();

      // Open the confirmation sheet.
      await tester.tap(find.widgetWithText(FilledButton, 'Finish Patrol'));
      await tester.pumpAndSettle();
      expect(find.text('Finish patrol?'), findsOneWidget);

      // Confirm (the sheet's Finish Patrol button).
      await tester.tap(find.widgetWithText(FilledButton, 'Finish Patrol').last);
      await tester.pumpAndSettle();

      expect(find.text('SUMMARY STUB'), findsOneWidget);
      final patrol = await repo.getPatrolById(id);
      expect(patrol!.status, PatrolStatus.completed);
    });

    testWidgets('cancelling the finish sheet keeps the patrol in progress',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final id = await seedInProgress();
      await tester.pumpWidget(wrapRouter(id, online: false));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Finish Patrol'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('SUMMARY STUB'), findsNothing);
      final patrol = await repo.getPatrolById(id);
      expect(patrol!.status, PatrolStatus.inProgress);
    });

    testWidgets('shows the GPS-unavailable card when permission is denied',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final id = await seedInProgress();
      await tester.pumpWidget(
          wrapRouter(id, online: false, location: _NoGpsLocation()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.gps_off), findsOneWidget);
      // Manual entry stays available despite no GPS.
      expect(find.text('Manual Waypoint'), findsOneWidget);
    });
  });

  group('PatrolSummaryScreen', () {
    testWidgets('shows duration and positions for a completed patrol',
        (tester) async {
      final id = await seedCompleted();
      await pumpScreen(tester, PatrolSummaryScreen(patrolId: id));

      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Positions recorded'), findsOneWidget);
    });
  });

  group('ManualWaypointScreen', () {
    testWidgets('rejects a blank coordinate and will not save', (tester) async {
      final id = await seedInProgress();
      await pumpScreen(tester, ManualWaypointScreen(patrolId: id));

      // Fields are pre-filled with a default; clearing one must fail validation.
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Latitude'), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Waypoint'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      // Validation blocked the save: no manual waypoint was persisted.
      final positions = await repo.getPositions(id);
      expect(positions.any((p) => p.captureMode.name == 'manual'), isFalse);
    });

    testWidgets('rejects an out-of-range latitude', (tester) async {
      final id = await seedInProgress();
      await pumpScreen(tester, ManualWaypointScreen(patrolId: id));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Latitude'), '999');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Waypoint'));
      await tester.pumpAndSettle();

      expect(find.text('Latitude -90..90'), findsOneWidget);
    });

    testWidgets('saves a manual waypoint with valid coordinates', (tester) async {
      final id = await seedInProgress();
      await pumpScreen(tester, ManualWaypointScreen(patrolId: id));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Latitude'), '8.035');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Longitude'), '80.905');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Waypoint'));
      await tester.pumpAndSettle();

      final positions = await repo.getPositions(id);
      expect(positions.any((p) => p.captureMode.name == 'manual'), isTrue);
    });
  });
}

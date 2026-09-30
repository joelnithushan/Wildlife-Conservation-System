import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show WidgetTester, addTearDown;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/routing/app_router.dart';
import 'package:wildlife_conservation_system/core/services/connectivity_service.dart';
import 'package:wildlife_conservation_system/core/services/storage_service.dart';
import 'package:wildlife_conservation_system/core/sync/sync_service.dart';
import 'package:wildlife_conservation_system/features/incidents/presentation/screens/incident_evidence_screen.dart';
import 'package:wildlife_conservation_system/features/incidents/presentation/screens/incident_location_screen.dart';
import 'package:wildlife_conservation_system/features/incidents/presentation/screens/incident_result_screen.dart';
import 'package:wildlife_conservation_system/features/incidents/presentation/screens/incident_review_detail_screen.dart';
import 'package:wildlife_conservation_system/features/incidents/presentation/screens/incident_review_queue_screen.dart';
import 'package:wildlife_conservation_system/features/incidents/presentation/screens/incident_review_screen.dart';
import 'package:wildlife_conservation_system/features/incidents/presentation/screens/new_incident_screen.dart';

// Convenience re-exports so widget tests can reference providers, fakes and
// domain types with a single `import '../helpers.dart';`.
export 'package:wildlife_conservation_system/core/database/app_database.dart'
    show AppDatabase, appDatabaseProvider;
export 'package:wildlife_conservation_system/core/enums/app_enums.dart';
export 'package:wildlife_conservation_system/core/routing/app_router.dart'
    show AppRoutes;
export 'package:wildlife_conservation_system/features/incidents/data/datasources/incident_evidence_source.dart'
    show CapturedEvidence;
export 'package:wildlife_conservation_system/features/incidents/presentation/providers/incident_providers.dart';
export 'package:wildlife_conservation_system/shared/demo/demo_data.dart'
    show DemoData;
export 'package:wildlife_conservation_system/shared/session/current_user.dart'
    show currentUserProvider;

/// Fresh in-memory database for each test (mirrors test/patrol/helpers.dart).
AppDatabase createIncidentTestDatabase() => AppDatabase(NativeDatabase.memory());

/// An already-closed database — writes fail, modelling local-storage failure.
Future<AppDatabase> createClosedDatabase() async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.close();
  return db;
}

/// Connectivity fake so submission/sync tests are deterministic.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({required bool online}) : _online = online;

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> get connectionChanges => _controller.stream;
}

/// Storage fake keyed by the object path — mirrors idempotent uploads (the
/// same incidentId/filename overwrites the same object).
class FakeStorageService implements StorageService {
  final Map<String, Uint8List> objects = {};
  int failuresRemaining = 0;

  @override
  Future<String> uploadIncidentEvidence({
    required String incidentId,
    required String filename,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw Exception('upload failed');
    }
    final path = 'incident-evidence/$incidentId/$filename';
    objects[path] = bytes;
    return 'https://example.test/$path';
  }

  @override
  Future<void> deleteIncidentEvidence({
    required String incidentId,
    required String filename,
  }) async {
    objects.remove('incident-evidence/$incidentId/$filename');
  }
}

/// Records what was pushed to the "remote" so sync round-trips can be
/// asserted (same idempotent upsert contract as the real writers).
class FakeRemoteWriter implements RemoteWriter {
  final Map<String, Map<String, dynamic>> documents = {};

  int get documentCount => documents.length;

  @override
  Future<void> upsert(
      String collection, String id, Map<String, dynamic> data) async {
    documents['$collection/$id'] = data;
  }
}

/// Sync-service fake with a controllable outcome so result/retry flows are
/// deterministic without hitting the real sync engine.
class FakeSyncService implements SyncService {
  FakeSyncService({this.failSync = false});

  bool failSync;
  int syncCalls = 0;
  final _phase = StreamController<SyncPhase>.broadcast();

  @override
  Future<SyncSummary> syncPendingIncidentData() async {
    syncCalls++;
    return failSync ? const SyncSummary(pushed: 0, failed: 1) : const SyncSummary(pushed: 1);
  }

  @override
  Future<SyncSummary> syncPendingPatrolData() async =>
      failSync ? const SyncSummary(pushed: 0, failed: 1) : const SyncSummary(pushed: 1);

  @override
  Future<SyncSummary> syncAllPendingData() async =>
      failSync ? const SyncSummary(pushed: 0, failed: 2) : const SyncSummary(pushed: 2);

  @override
  Stream<SyncPhase> get phase => _phase.stream;
}

/// GoRouter with every UC02 route registered so screens can navigate in tests.
GoRouter uc02TestRouter({String initialLocation = '/'}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
        ),
        GoRoute(
          path: AppRoutes.newIncident,
          builder: (context, state) => const NewIncidentScreen(),
        ),
        GoRoute(
          path: AppRoutes.incidentEvidence,
          builder: (context, state) => const IncidentEvidenceScreen(),
        ),
        GoRoute(
          path: AppRoutes.incidentLocation,
          builder: (context, state) => const IncidentLocationScreen(),
        ),
        GoRoute(
          path: AppRoutes.incidentReview,
          builder: (context, state) => const IncidentReviewScreen(),
        ),
        GoRoute(
          path: AppRoutes.incidentResult,
          builder: (context, state) => IncidentResultScreen(
              reportId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: AppRoutes.incidentReviewQueue,
          builder: (context, state) => const IncidentReviewQueueScreen(),
        ),
        GoRoute(
          path: AppRoutes.incidentReviewDetail,
          builder: (context, state) => IncidentReviewDetailScreen(
              reportId: state.pathParameters['id']!),
        ),
      ],
    );

/// Pumps the UC02 test router at [initialLocation] inside [container].
///
/// The [screen] argument is accepted for readability at call sites but the
/// router itself decides what to build — pass `const SizedBox.shrink()`.
/// [surfaceSize] enlarges the test viewport for tall screens (e.g. the
/// reviewer's decision controls below the fold on the default 800x600).
Future<void> pumpUc02Screen(
  WidgetTester tester,
  Widget screen, {
  required ProviderContainer container,
  String initialLocation = '/',
  Size surfaceSize = const Size(800, 1200),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: uc02TestRouter(initialLocation: initialLocation),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

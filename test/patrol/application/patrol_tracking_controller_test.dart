import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/errors/exceptions.dart';
import 'package:wildlife_conservation_system/core/sync/sync_service.dart';
import 'package:wildlife_conservation_system/features/patrol/application/patrol_tracking_controller.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/providers/patrol_providers.dart';
import 'package:wildlife_conservation_system/shared/services/location_service.dart';

import '../helpers.dart';

/// Location service that always fails — models GPS unavailable / denied.
class NoGpsLocationService implements LocationService {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<({double latitude, double longitude})> getCurrentPosition() async =>
      throw const PermissionException('no gps');

  @override
  Stream<({double latitude, double longitude})> positionStream() =>
      const Stream.empty();
}

/// Location service that grants permission and returns/streams a fixed fix.
class GoodGpsLocationService implements LocationService {
  GoodGpsLocationService({this.stream});

  final Stream<({double latitude, double longitude})>? stream;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<({double latitude, double longitude})> getCurrentPosition() async =>
      (latitude: 8.5, longitude: 80.5);

  @override
  Stream<({double latitude, double longitude})> positionStream() =>
      stream ?? const Stream.empty();
}

/// Sync service with a canned summary (or throwing) so runSync branches are
/// exercised without touching Firestore.
class FakeSyncService implements SyncService {
  FakeSyncService({this.summary, this.throws = false});
  final SyncSummary? summary;
  final bool throws;

  @override
  Future<SyncSummary> syncAllPendingData() async {
    if (throws) throw const RepositoryException('network down');
    return summary ?? const SyncSummary(pushed: 1);
  }

  @override
  Future<SyncSummary> syncPendingPatrolData() => syncAllPendingData();

  @override
  Future<SyncSummary> syncPendingIncidentData() => syncAllPendingData();

  @override
  Stream<SyncPhase> get phase => const Stream.empty();
}

void main() {
  late AppDatabase db;

  ProviderContainer makeContainer({
    LocationService? location,
    SyncService? sync,
  }) {
    return ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      locationServiceProvider
          .overrideWithValue(location ?? NoGpsLocationService()),
      if (sync != null) syncServiceProvider.overrideWithValue(sync),
    ]);
  }

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  group('GPS capture', () {
    test('permission denied sets an error but keeps manual entry working',
        () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final controller =
          container.read(patrolTrackingControllerProvider.notifier)
            ..attach('patrol_1');

      await controller.beginTracking();
      expect(container.read(patrolTrackingControllerProvider).gpsUnavailable,
          isTrue);

      await controller.addManualWaypoint(8.03, 80.89);
      final positions =
          await container.read(patrolPositionsProvider('patrol_1').future);
      expect(positions, hasLength(1));
      expect(positions.single.captureMode, CaptureMode.manual);
    });

    test('captureGpsOnce persists a gps position and clears any error',
        () async {
      final container = makeContainer(location: GoodGpsLocationService());
      addTearDown(container.dispose);
      final controller =
          container.read(patrolTrackingControllerProvider.notifier)
            ..attach('patrol_1');

      await controller.captureGpsOnce();

      final positions =
          await container.read(patrolPositionsProvider('patrol_1').future);
      expect(positions, hasLength(1));
      expect(positions.single.captureMode, CaptureMode.gps);
      final state = container.read(patrolTrackingControllerProvider);
      expect(state.gpsUnavailable, isFalse);
      expect(state.lastCaptureMode, CaptureMode.gps);
    });

    test('captureGpsOnce records an error and saves nothing when GPS fails',
        () async {
      final container = makeContainer(location: NoGpsLocationService());
      addTearDown(container.dispose);
      final controller =
          container.read(patrolTrackingControllerProvider.notifier)
            ..attach('patrol_1');

      await controller.captureGpsOnce();

      expect(container.read(patrolTrackingControllerProvider).gpsUnavailable,
          isTrue);
      final positions =
          await container.read(patrolPositionsProvider('patrol_1').future);
      expect(positions, isEmpty);
    });

    test('beginTracking streams a gps fix into a saved position', () async {
      final controller = StreamController<({double latitude, double longitude})>();
      final container = makeContainer(
          location: GoodGpsLocationService(stream: controller.stream));
      addTearDown(container.dispose);
      addTearDown(controller.close);
      final notifier =
          container.read(patrolTrackingControllerProvider.notifier)
            ..attach('patrol_1');

      await notifier.beginTracking();
      expect(container.read(patrolTrackingControllerProvider).isTracking, isTrue);

      controller.add((latitude: 8.1, longitude: 80.1));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final positions =
          await container.read(patrolPositionsProvider('patrol_1').future);
      expect(positions, hasLength(1));
      expect(positions.single.captureMode, CaptureMode.gps);
    });

    test('a stream error marks GPS unavailable without crashing', () async {
      final controller = StreamController<({double latitude, double longitude})>();
      final container = makeContainer(
          location: GoodGpsLocationService(stream: controller.stream));
      addTearDown(container.dispose);
      addTearDown(controller.close);
      final notifier =
          container.read(patrolTrackingControllerProvider.notifier)
            ..attach('patrol_1');

      await notifier.beginTracking();
      controller.addError(StateError('gps lost'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(container.read(patrolTrackingControllerProvider).gpsUnavailable,
          isTrue);
    });

    test('saving a position before attaching throws', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final controller =
          container.read(patrolTrackingControllerProvider.notifier);

      expect(() => controller.addManualWaypoint(8.0, 80.0),
          throwsA(isA<RepositoryException>()));
    });
  });

  group('runSync', () {
    test('moves pending records to synchronized and reports the count',
        () async {
      final container = makeContainer(
          location: GoodGpsLocationService(),
          sync: FakeSyncService(summary: const SyncSummary(pushed: 1)));
      addTearDown(container.dispose);
      final controller =
          container.read(patrolTrackingControllerProvider.notifier)
            ..attach('patrol_1');
      await controller.addManualWaypoint(8.03, 80.89);

      await controller.runSync();

      final state = container.read(patrolTrackingControllerProvider);
      expect(state.isSyncing, isFalse);
      expect(state.syncMessage, contains('Synchronized'));
    });

    test('reports an incomplete sync when some records fail', () async {
      final container = makeContainer(
          sync: FakeSyncService(
              summary: const SyncSummary(pushed: 1, failed: 2)));
      addTearDown(container.dispose);
      final controller =
          container.read(patrolTrackingControllerProvider.notifier)
            ..attach('patrol_1');

      await controller.runSync();

      final state = container.read(patrolTrackingControllerProvider);
      expect(state.isSyncing, isFalse);
      expect(state.syncMessage, contains('incomplete'));
    });

    test('keeps data on device and reports failure when sync throws', () async {
      final container = makeContainer(sync: FakeSyncService(throws: true));
      addTearDown(container.dispose);
      final controller =
          container.read(patrolTrackingControllerProvider.notifier)
            ..attach('patrol_1');

      await controller.runSync();

      final state = container.read(patrolTrackingControllerProvider);
      expect(state.isSyncing, isFalse);
      expect(state.syncMessage, contains('Sync failed'));
    });
  });
}

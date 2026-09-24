import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/errors/exceptions.dart';
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

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = createTestDatabase();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      locationServiceProvider.overrideWithValue(NoGpsLocationService()),
    ]);
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('GPS unavailable sets an error but keeps manual entry working', () async {
    final controller =
        container.read(patrolTrackingControllerProvider.notifier)..attach('patrol_1');

    await controller.beginTracking();
    expect(container.read(patrolTrackingControllerProvider).gpsUnavailable, isTrue);

    // Manual fallback still records a position.
    await controller.addManualWaypoint(8.03, 80.89);
    final positions =
        await container.read(patrolPositionsProvider('patrol_1').future);
    expect(positions, hasLength(1));
    expect(positions.single.captureMode, CaptureMode.manual);
  });

  test('runSync moves pending records to synchronized', () async {
    final controller =
        container.read(patrolTrackingControllerProvider.notifier)..attach('patrol_1');
    await controller.addManualWaypoint(8.03, 80.89);

    expect(await container.read(pendingRecordCountProvider.future), 1);

    await controller.runSync();

    final pendingAfter =
        await container.read(pendingRecordCountProvider.future);
    expect(pendingAfter, 0);
  });
}

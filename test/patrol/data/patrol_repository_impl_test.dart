import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/errors/exceptions.dart';
import 'package:wildlife_conservation_system/features/patrol/data/datasources/patrol_local_data_source.dart';
import 'package:wildlife_conservation_system/features/patrol/data/repositories/patrol_repository_impl.dart';
import 'package:wildlife_conservation_system/shared/models/patrol_position.dart';

import '../helpers.dart';

/// Data source whose writes always fail, to exercise error propagation.
class _ThrowingLocalDataSource extends PatrolLocalDataSource {
  _ThrowingLocalDataSource(super.db);

  @override
  Future<void> upsertPatrol(patrol, {required DateTime now}) async {
    throw const LocalStorageException('disk full');
  }
}

void main() {
  late AppDatabase db;
  late PatrolRepositoryImpl repo;
  final fixedNow = DateTime.utc(2026, 9, 23, 8);

  setUp(() {
    db = createTestDatabase();
    repo = PatrolRepositoryImpl(
      local: PatrolLocalDataSource(db),
      resolveRoute: testRouteResolver,
      clock: () => fixedNow,
    );
  });

  tearDown(() => db.close());

  Future<String> assign() async {
    final patrol = await repo.assignRoute(
      routeId: testRoute.id,
      rangerId: 'R001',
      parkId: 'PARK-MIN',
      scheduledFor: fixedNow.add(const Duration(hours: 2)),
    );
    return patrol.id;
  }

  group('Assignment (UC01-S01)', () {
    test('creates one assigned patrol with a stable id, pending sync', () async {
      final patrol = await repo.assignRoute(
        routeId: testRoute.id,
        rangerId: 'R001',
        parkId: 'PARK-MIN',
        scheduledFor: fixedNow,
      );
      expect(patrol.status, PatrolStatus.assigned);
      expect(patrol.id, isNotEmpty);
      expect(patrol.syncState, SyncState.pending);

      final stored = await repo.getPatrolById(patrol.id);
      expect(stored, isNotNull);
      expect(stored!.id, patrol.id);
    });

    test('assigned patrol appears for the correct ranger only', () async {
      await assign();
      expect((await repo.getAssignedPatrols('R001')), hasLength(1));
      expect((await repo.getAssignedPatrols('R002')), isEmpty);
    });

    test('empty patrol list for a ranger with no patrols', () async {
      expect(await repo.getAssignedPatrols('NOBODY'), isEmpty);
    });

    test('save failure surfaces as LocalStorageException (no silent loss)',
        () async {
      final failingRepo = PatrolRepositoryImpl(
        local: _ThrowingLocalDataSource(db),
        resolveRoute: testRouteResolver,
        clock: () => fixedNow,
      );
      expect(
        () => failingRepo.assignRoute(
          routeId: testRoute.id,
          rangerId: 'R001',
          parkId: 'PARK-MIN',
          scheduledFor: fixedNow,
        ),
        throwsA(isA<LocalStorageException>()),
      );
    });
  });

  group('Start patrol (UC01-S02)', () {
    test('assigned -> inProgress records startedAt', () async {
      final id = await assign();
      final started = await repo.startPatrol(id);
      expect(started.status, PatrolStatus.inProgress);
      expect(started.startedAt, fixedNow);
    });

    test('rejects duplicate start', () async {
      final id = await assign();
      await repo.startPatrol(id);
      expect(() => repo.startPatrol(id), throwsA(isA<ValidationException>()));
    });

    test('rejects starting a completed patrol', () async {
      final id = await assign();
      await repo.startPatrol(id);
      await repo.completePatrol(id);
      expect(() => repo.startPatrol(id), throwsA(isA<ValidationException>()));
    });
  });

  group('Positions', () {
    Future<String> startedPatrol() async {
      final id = await assign();
      await repo.startPatrol(id);
      return id;
    }

    test('GPS position saved with captureMode gps and pending sync', () async {
      final id = await startedPatrol();
      await repo.savePosition(PatrolPosition.create(
        patrolId: id,
        latitude: 8.03,
        longitude: 80.89,
        timestamp: fixedNow,
        captureMode: CaptureMode.gps,
      ));
      final positions = await repo.getPositions(id);
      expect(positions, hasLength(1));
      expect(positions.single.captureMode, CaptureMode.gps);
      expect(positions.single.syncState, SyncState.pending);
    });

    test('manual waypoint saved with captureMode manual', () async {
      final id = await startedPatrol();
      await repo.savePosition(PatrolPosition.create(
        patrolId: id,
        latitude: 8.04,
        longitude: 80.895,
        timestamp: fixedNow,
        captureMode: CaptureMode.manual,
      ));
      final positions = await repo.getPositions(id);
      expect(positions.single.captureMode, CaptureMode.manual);
    });
  });

  group('Completion & coverage (UC01-S02)', () {
    test('inProgress -> completed sets completedAt and coverage', () async {
      final id = await assign();
      await repo.startPatrol(id);
      // Visit both planned points -> 100% coverage.
      for (final c in testRoute.plannedPath) {
        await repo.savePosition(PatrolPosition.create(
          patrolId: id,
          latitude: c.latitude,
          longitude: c.longitude,
          timestamp: fixedNow,
        ));
      }
      final completed = await repo.completePatrol(id);
      expect(completed.status, PatrolStatus.completed);
      expect(completed.completedAt, fixedNow);
      expect(completed.coveragePercent, 100);
    });

    test('rejects completing a patrol that is not in progress', () async {
      final id = await assign();
      expect(() => repo.completePatrol(id), throwsA(isA<ValidationException>()));
    });

    test('coverage stays within 0..100 with no positions', () async {
      final id = await assign();
      await repo.startPatrol(id);
      final coverage = await repo.calculateCoverage(id);
      expect(coverage, inInclusiveRange(0, 100));
    });
  });

  group('Pending sync queue', () {
    test('assigned patrol is listed as pending', () async {
      await assign();
      expect(await repo.getPendingPatrols(), hasLength(1));
    });
  });
}

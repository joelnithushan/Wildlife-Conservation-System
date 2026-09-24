import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/theme/app_theme.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/providers/patrol_providers.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/screens/assign_patrol_route_screen.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/screens/my_patrols_screen.dart';
import 'package:wildlife_conservation_system/shared/models/patrol.dart';
import 'package:wildlife_conservation_system/shared/models/patrol_position.dart';
import 'package:wildlife_conservation_system/shared/repositories/patrol_repository.dart';
import 'package:wildlife_conservation_system/shared/session/current_user.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';

/// Fake repo returning canned patrols so the list screen renders with data.
class _FakePatrolRepo implements PatrolRepository {
  @override
  Future<List<Patrol>> getAssignedPatrols(String rangerId) async => [
        Patrol(
          id: 'p_today',
          routeId: 'RT-07',
          rangerId: rangerId,
          parkId: 'PARK-MIN',
          scheduledFor: DateTime.now().copyWith(hour: 6, minute: 30),
          assignedAt: DateTime.now(),
          status: PatrolStatus.assigned,
        ),
        Patrol(
          id: 'p_up',
          routeId: 'RT-05',
          rangerId: rangerId,
          parkId: 'PARK-MIN',
          scheduledFor: DateTime.now().add(const Duration(days: 1)),
          assignedAt: DateTime.now(),
          status: PatrolStatus.assigned,
        ),
      ];

  @override
  Future<Patrol?> getPatrolById(String id) async => null;
  @override
  Future<Patrol> assignRoute(
          {required String routeId,
          required String rangerId,
          required String parkId,
          required DateTime scheduledFor}) =>
      throw UnimplementedError();
  @override
  Future<Patrol> startPatrol(String id) => throw UnimplementedError();
  @override
  Future<void> savePosition(PatrolPosition position) async {}
  @override
  Future<List<PatrolPosition>> getPositions(String patrolId) async => [];
  @override
  Future<Patrol> completePatrol(String id) => throw UnimplementedError();
  @override
  Future<double> calculateCoverage(String id) async => 0;
  @override
  Future<List<Patrol>> getPendingPatrols() async => [];
}

class _RangerUser extends CurrentUserNotifier {
  @override
  build() => DemoData.rangerPerera;
}

void main() {
  testWidgets('golden: My Patrols (ranger, populated)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        patrolRepositoryProvider.overrideWithValue(_FakePatrolRepo()),
        currentUserProvider.overrideWith(_RangerUser.new),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const MyPatrolsScreen()),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MyPatrolsScreen),
      matchesGoldenFile('goldens/my_patrols.png'),
    );
  });

  testWidgets('golden: Assign Patrol Route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
          theme: AppTheme.light(), home: const AssignPatrolRouteScreen()),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AssignPatrolRouteScreen),
      matchesGoldenFile('goldens/assign_patrol_route.png'),
    );
  });
}

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/providers/patrol_providers.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';
import 'package:wildlife_conservation_system/shared/session/current_user.dart';

/// Integration checks tying UC01 to the authenticated session: the assignment
/// roster is scoped to the manager's park, and a ranger only ever sees their own
/// patrols. No live Firebase — offline Drift + demo roster.
void main() {
  group('Manager assignment roster (authenticated context)', () {
    test('1. lists only available rangers in the manager\'s park', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Default demo session is the Park Manager of PARK-MIN.
      final roster = container.read(availableRangersProvider);

      expect(roster.map((u) => u.id), containsAll(<String>['R001', 'R002']));
      expect(roster.every((u) => u.role == UserRole.ranger), isTrue,
          reason: 'only rangers are assignable to patrols');
      expect(roster.any((u) => u.id == 'CLO001'), isFalse,
          reason: 'liaison officers are not assignable to patrols');
    });

    test('2. excludes rangers from a different park', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(currentUserProvider.notifier).signIn(const AppUser(
            id: 'PMX',
            name: 'Other Manager',
            email: 'other@wildguard.lk',
            role: UserRole.parkManager,
            parkId: 'PARK-OTHER',
          ));

      expect(container.read(availableRangersProvider), isEmpty);
    });
  });

  group('Ranger patrol filtering (no cross-ranger leak)', () {
    test('3. My Patrols returns only the authenticated ranger\'s patrols',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
      ]);
      addTearDown(() {
        container.dispose();
        db.close();
      });

      final repo = container.read(patrolRepositoryProvider);
      await repo.assignRoute(
        routeId: 'RT-07',
        rangerId: 'R001',
        parkId: 'PARK-MIN',
        scheduledFor: DateTime.utc(2026, 9, 23, 8),
      );
      await repo.assignRoute(
        routeId: 'RT-05',
        rangerId: 'R002',
        parkId: 'PARK-MIN',
        scheduledFor: DateTime.utc(2026, 9, 23, 9),
      );

      // Authenticate as ranger R001 (K. Perera).
      container.read(currentUserProvider.notifier).signIn(DemoData.rangerPerera);
      final mine = await container.read(myPatrolsProvider.future);

      expect(mine, hasLength(1));
      expect(mine.single.rangerId, 'R001');
    });
  });
}

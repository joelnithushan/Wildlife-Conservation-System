import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/patrol/domain/entities/patrol.dart';
import 'package:wildlife_conservation_system/shared/models/enums.dart';

void main() {
  group('Patrol entity', () {
    const patrol = Patrol(
      id: 'p1',
      rangerId: 'r1',
      status: PatrolStatus.assigned,
    );

    test('equality holds when id and status match', () {
      const same = Patrol(
        id: 'p1',
        rangerId: 'r1',
        status: PatrolStatus.assigned,
      );
      expect(patrol, equals(same));
    });

    test('inequality when id differs', () {
      const different = Patrol(
        id: 'p2',
        rangerId: 'r1',
        status: PatrolStatus.assigned,
      );
      expect(patrol, isNot(equals(different)));
    });

    test('default syncStatus is pending', () {
      expect(patrol.syncStatus, SyncStatus.pending);
    });
  });
}

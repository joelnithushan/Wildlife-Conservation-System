import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/utils/id_generator.dart';
import 'package:wildlife_conservation_system/shared/models/models.dart';

void main() {
  group('Stable client-generated IDs', () {
    test('IdGenerator produces unique, prefixed IDs', () {
      final a = IdGenerator.newId('patrol');
      final b = IdGenerator.newId('patrol');
      expect(a, startsWith('patrol_'));
      expect(a, isNot(b));
    });

    test('factory-created record keeps its ID across copyWith and serialization',
        () {
      final patrol = Patrol.create(
        routeId: 'RT-07',
        rangerId: 'R001',
        parkId: 'PARK-MIN',
        scheduledFor: DateTime.utc(2026, 9, 23),
        assignedAt: DateTime.utc(2026, 9, 23),
      );
      final started = patrol.copyWith(status: PatrolStatus.inProgress);
      final restored = Patrol.fromMap(started.toMap());

      // The ID never changes — this is what makes offline sync retries idempotent.
      expect(started.id, patrol.id);
      expect(restored.id, patrol.id);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';

void main() {
  group('AppUser.ageAsOf (age derived from DOB)', () {
    AppUser withDob(DateTime? dob) => AppUser(
          id: 'u1',
          name: 'Test User',
          role: UserRole.ranger,
          parkId: 'PARK-MIN',
          dateOfBirth: dob,
        );

    test('returns null when no date of birth is set', () {
      expect(withDob(null).ageAsOf(DateTime(2026, 1, 1)), isNull);
    });

    test('counts full years before the birthday has occurred this year', () {
      // Born 1992-08-03; as of 2026-08-02 the birthday has NOT happened → 33.
      expect(
        withDob(DateTime(1992, 8, 3)).ageAsOf(DateTime(2026, 8, 2)),
        33,
      );
    });

    test('ticks over exactly on the birthday', () {
      expect(
        withDob(DateTime(1992, 8, 3)).ageAsOf(DateTime(2026, 8, 3)),
        34,
      );
    });

    test('counts the extra year after the birthday', () {
      expect(
        withDob(DateTime(1992, 8, 3)).ageAsOf(DateTime(2026, 8, 4)),
        34,
      );
    });

    test('handles a same-year date (never negative)', () {
      expect(
        withDob(DateTime(2026, 12, 31)).ageAsOf(DateTime(2026, 1, 1)),
        0,
      );
    });
  });

  group('AppUser serialization round-trip', () {
    final user = AppUser(
      id: 'uid-1',
      name: 'Kumar Perera',
      username: 'ranger_kumar_001',
      email: 'ranger1@wildguard.lk',
      mobileNumber: '0770000002',
      personalMobileNumber: '0710000002',
      nic: '199212345672',
      gender: Gender.male,
      dateOfBirth: DateTime(1992, 8, 3),
      photoData: 'QUJD', // base64 for "ABC"
      role: UserRole.ranger,
      parkId: 'PARK-MIN',
      isAvailable: false,
      isActive: true,
    );

    test('toMap → fromMap preserves every field', () {
      final restored = AppUser.fromMap(user.toMap());
      expect(restored, user);
    });

    test('new fields survive the round-trip', () {
      final restored = AppUser.fromMap(user.toMap());
      expect(restored.username, 'ranger_kumar_001');
      expect(restored.mobileNumber, '0770000002');
      expect(restored.personalMobileNumber, '0710000002');
      expect(restored.nic, '199212345672');
      expect(restored.gender, Gender.male);
      expect(restored.dateOfBirth, DateTime(1992, 8, 3));
      expect(restored.photoData, 'QUJD');
    });

    test('tolerates a legacy document missing the new fields', () {
      final legacy = AppUser.fromMap({
        'id': 'old-1',
        'name': 'Old User',
        'email': 'old@wildguard.lk',
        'role': 'parkManager',
        'parkId': 'PARK-MIN',
      });
      expect(legacy.username, '');
      expect(legacy.gender, isNull);
      expect(legacy.dateOfBirth, isNull);
      expect(legacy.photoData, '');
      expect(legacy.age, isNull);
      expect(legacy.role, UserRole.parkManager);
    });

    test('isAdmin / isResponder reflect the role', () {
      expect(user.isResponder, isTrue); // ranger
      expect(user.isAdmin, isFalse);
      final admin = user.copyWith(role: UserRole.admin);
      expect(admin.isAdmin, isTrue);
      expect(admin.isResponder, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/admin/domain/username_generator.dart';

void main() {
  String gen(String name, UserRole role, [Set<String> taken = const {}]) =>
      UsernameGenerator.generate(
        fullName: name,
        role: role,
        existingUsernames: taken,
      );

  group('UsernameGenerator', () {
    test('uses role_firstname_seq lowercase format', () {
      expect(gen('Kumar Ravi', UserRole.ranger), 'ranger_kumar_001');
      expect(gen('Sunil Perera', UserRole.parkManager), 'manager_sunil_001');
      expect(gen('Nimal S.', UserRole.communityLiaisonOfficer), 'clo_nimal_001');
      expect(gen('Amara', UserRole.conservationResearcher),
          'researcher_amara_001');
    });

    test('increments the sequence to stay unique within role + first name', () {
      final taken = {'ranger_kumar_001', 'ranger_kumar_002'};
      expect(gen('Kumar Ravi', UserRole.ranger, taken), 'ranger_kumar_003');
    });

    test('different first names and roles start their own sequence', () {
      final taken = {'ranger_kumar_001'};
      expect(gen('Sunil X', UserRole.ranger, taken), 'ranger_sunil_001');
      expect(gen('Kumar Y', UserRole.parkManager, taken), 'manager_kumar_001');
    });

    test('is case-insensitive when checking for collisions', () {
      final taken = {'RANGER_KUMAR_001'};
      expect(gen('Kumar', UserRole.ranger, taken), 'ranger_kumar_002');
    });

    test('sanitizes the first name to a-z0-9 and falls back to user', () {
      expect(gen('  Él!ya  Stone', UserRole.ranger), 'ranger_lya_001');
      expect(gen('***', UserRole.ranger), 'ranger_user_001');
    });
  });
}

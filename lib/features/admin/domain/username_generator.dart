import '../../../core/enums/app_enums.dart';

/// Generates login usernames in the WildGuard contract format:
///
///   `{roleCode}_{firstName}_{seq}`   e.g. `ranger_kumar_001`
///
/// - `roleCode`  — [UserRoleX.usernameCode] (ranger / manager / clo / researcher)
/// - `firstName` — first word of the full name, lowercased, a–z0–9 only
/// - `seq`       — zero-padded 3-digit sequence, unique within the same
///                 role + first-name prefix (collisions auto-increment)
///
/// Pure and side-effect free so it is fully unit-testable. Callers pass the set
/// of usernames already in use (fetched from Firestore) to guarantee uniqueness.
abstract final class UsernameGenerator {
  /// Builds a unique username for [fullName] + [role], avoiding anything in
  /// [existingUsernames] (compared case-insensitively).
  static String generate({
    required String fullName,
    required UserRole role,
    required Set<String> existingUsernames,
  }) {
    final taken = existingUsernames.map((u) => u.toLowerCase()).toSet();
    final prefix = '${role.usernameCode}_${_firstName(fullName)}_';

    for (var seq = 1; seq < 1000; seq++) {
      final candidate = '$prefix${seq.toString().padLeft(3, '0')}';
      if (!taken.contains(candidate)) return candidate;
    }
    // Astronomically unlikely (>999 same-name users in one role); fall back to a
    // longer sequence rather than ever returning a duplicate.
    var seq = 1000;
    while (taken.contains('$prefix$seq')) {
      seq++;
    }
    return '$prefix$seq';
  }

  /// First word of [fullName], lowercased and reduced to a–z0–9.
  /// Falls back to `user` when nothing usable remains.
  static String _firstName(String fullName) {
    final first = fullName.trim().split(RegExp(r'\s+')).first;
    final clean = first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return clean.isEmpty ? 'user' : clean;
  }
}

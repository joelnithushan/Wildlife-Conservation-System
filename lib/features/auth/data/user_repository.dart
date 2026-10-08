import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/enums/app_enums.dart';
import '../../../shared/models/app_user.dart';
import '../domain/auth_session.dart';

/// Result of loading a WildGuard profile for an authenticated identity.
///
/// Either a valid [user] or a [ProfileIssue] describing why the profile cannot
/// be used (missing / inactive / unsupported role / incomplete).
class ProfileResult {
  const ProfileResult._({this.user, this.issue});

  const ProfileResult.ok(AppUser user) : this._(user: user);
  const ProfileResult.problem(ProfileIssue issue) : this._(issue: issue);

  final AppUser? user;
  final ProfileIssue? issue;

  bool get isOk => user != null;
}

/// Reads WildGuard user profiles from Firestore (`users/{uid}`).
///
/// Separate from [AuthService] on purpose: Firebase Auth owns identity/session,
/// this owns the business profile + role.
abstract class UserRepository {
  /// Loads and validates the profile for [uid]. Never throws for a missing /
  /// malformed document — returns a [ProfileResult] describing the issue.
  Future<ProfileResult> getUserProfile(String uid);

  /// Resolves a login [username] (e.g. `ranger_kumar_001`) to its account email
  /// so the user can sign in with Firebase Auth. Returns null when no active
  /// account has that username.
  Future<String?> findEmailByUsername(String username);
}

/// [UserRepository] backed by Cloud Firestore.
class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<ProfileResult> getUserProfile(String uid) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();

    if (!snapshot.exists) {
      return const ProfileResult.problem(ProfileIssue.missing);
    }
    return validateProfile(uid, snapshot.data());
  }

  @override
  Future<String?> findEmailByUsername(String username) async {
    final handle = username.trim().toLowerCase();
    if (handle.isEmpty) return null;
    final query = await _firestore
        .collection(FirestoreCollections.users)
        .where('username', isEqualTo: handle)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final email = query.docs.first.data()['email'] as String?;
    return (email == null || email.isEmpty) ? null : email;
  }
}

/// Validates a raw Firestore user document into a [ProfileResult].
///
/// Pure and Firebase-free so it is fully unit-testable. The document id is the
/// authoritative [AppUser.id]; the stored `id` field is ignored to guarantee it
/// always matches the Firebase Auth UID.
ProfileResult validateProfile(String uid, Map<String, dynamic>? data) {
  if (data == null) return const ProfileResult.problem(ProfileIssue.missing);

  final role = parseSupportedRole(data['role']);
  if (role == null) {
    return const ProfileResult.problem(ProfileIssue.unsupportedRole);
  }

  final name = (data['name'] as String?)?.trim() ?? '';
  final parkId = (data['parkId'] as String?)?.trim() ?? '';
  // Every staff profile needs a name. A park is required for operational roles
  // but not for the system admin, who is not tied to a single park.
  final needsPark = role != UserRole.admin;
  if (name.isEmpty || (needsPark && parkId.isEmpty)) {
    return const ProfileResult.problem(ProfileIssue.incomplete);
  }

  final isActive = data['isActive'] as bool? ?? true;
  if (!isActive) {
    return const ProfileResult.problem(ProfileIssue.inactive);
  }

  // Build from the full document so the profile screen has every field, then
  // force the authoritative id/role/isActive that we validated above.
  final user = AppUser.fromMap({...data, 'id': uid}).copyWith(
    name: name,
    role: role,
    parkId: parkId,
    isActive: true,
  );
  return ProfileResult.ok(user);
}

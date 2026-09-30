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
  if (name.isEmpty || parkId.isEmpty) {
    return const ProfileResult.problem(ProfileIssue.incomplete);
  }

  final isActive = data['isActive'] as bool? ?? true;
  if (!isActive) {
    return const ProfileResult.problem(ProfileIssue.inactive);
  }

  return ProfileResult.ok(
    AppUser(
      id: uid,
      name: name,
      email: (data['email'] as String?)?.trim() ?? '',
      role: role,
      parkId: parkId,
      isAvailable: data['isAvailable'] as bool? ?? true,
      isActive: true,
    ),
  );
}

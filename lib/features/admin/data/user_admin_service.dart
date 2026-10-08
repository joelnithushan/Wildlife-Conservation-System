import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/services/secondary_firebase.dart';
import '../../../shared/models/app_user.dart';
import '../domain/username_generator.dart';

/// All fields the admin collects when creating a staff account. Every field is
/// compulsory except [photoBytes], which is required by the UI but optional here
/// so the service stays reusable/testable.
class NewUserInput {
  const NewUserInput({
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
    required this.parkId,
    required this.mobileNumber,
    required this.personalMobileNumber,
    required this.nic,
    required this.gender,
    required this.dateOfBirth,
    this.photoBytes,
  });

  final String fullName;
  final String email;
  final String password;
  final UserRole role;
  final String parkId;
  final String mobileNumber;
  final String personalMobileNumber;
  final String nic;
  final Gender gender;
  final DateTime dateOfBirth;
  final Uint8List? photoBytes;
}

/// Raised when account creation/update fails, with a user-friendly [message].
class UserAdminException implements Exception {
  const UserAdminException(this.message);
  final String message;
  @override
  String toString() => 'UserAdminException: $message';
}

/// Admin-only account management: create / list / update / delete staff users.
///
/// Creation uses a SECONDARY Firebase app so the admin is never signed out
/// (Firebase Auth otherwise switches the session to the newly created user).
/// See AGENTS.md §35 — this is supporting infrastructure, not a graded use case.
class UserAdminService {
  UserAdminService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  /// All staff accounts, sorted by name. Excludes admin accounts (the admin
  /// manages operational staff, not other admins).
  Future<List<AppUser>> listUsers() async {
    final snap = await _users.get();
    final users = snap.docs
        .map((d) => AppUser.fromMap({...d.data(), 'id': d.id}))
        .where((u) => u.role != UserRole.admin)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  Future<Set<String>> _existingUsernames() async {
    final snap = await _users.get();
    return snap.docs
        .map((d) => (d.data()['username'] as String?) ?? '')
        .where((u) => u.isNotEmpty)
        .toSet();
  }

  /// Creates a staff account: Firebase Auth user + Firestore profile
  /// (+ optional profile picture in Storage). Returns the created [AppUser].
  Future<AppUser> createUser(NewUserInput input) async {
    final username = UsernameGenerator.generate(
      fullName: input.fullName,
      role: input.role,
      existingUsernames: await _existingUsernames(),
    );

    return withSecondaryFirebaseApp(name: 'wg_user_admin', (app) async {
      final auth = FirebaseAuth.instanceFor(app: app);
      String uid;
      try {
        final cred = await auth.createUserWithEmailAndPassword(
          email: input.email.trim(),
          password: input.password,
        );
        uid = cred.user!.uid;
      } on FirebaseAuthException catch (e) {
        throw UserAdminException(_authMessage(e.code));
      }

      var photoUrl = '';
      if (input.photoBytes != null) {
        photoUrl = await _uploadPhoto(uid, input.photoBytes!);
      }

      final user = AppUser(
        id: uid,
        name: input.fullName.trim(),
        username: username,
        email: input.email.trim(),
        mobileNumber: input.mobileNumber.trim(),
        personalMobileNumber: input.personalMobileNumber.trim(),
        nic: input.nic.trim(),
        gender: input.gender,
        dateOfBirth: input.dateOfBirth,
        photoUrl: photoUrl,
        role: input.role,
        parkId: input.parkId.trim(),
      );
      await _users.doc(uid).set(user.toMap());
      await auth.signOut();
      return user;
    });
  }

  /// Updates an existing profile (admin edit). Email/role/username are part of the
  /// account identity and should be passed unchanged from the loaded [user].
  /// Optionally replaces the profile picture with [newPhotoBytes].
  Future<AppUser> updateUser(AppUser user, {Uint8List? newPhotoBytes}) async {
    var next = user;
    if (newPhotoBytes != null) {
      next = next.copyWith(photoUrl: await _uploadPhoto(next.id, newPhotoBytes));
    }
    await _users.doc(next.id).set(next.toMap());
    return next;
  }

  /// Removes a user's profile (and profile picture). This locks the account out
  /// of WildGuard — login requires a valid profile. The underlying Firebase Auth
  /// record can only be fully removed with the Admin SDK (server-side), which is
  /// intentionally out of scope for this client app (AGENTS.md §54).
  Future<void> deleteUser(AppUser user) async {
    await _users.doc(user.id).delete();
    try {
      await _storage.ref('profile_pictures/${user.id}.jpg').delete();
    } catch (_) {
      // No picture / already gone — ignore.
    }
  }

  Future<String> _uploadPhoto(String uid, Uint8List bytes) async {
    final ref = _storage.ref('profile_pictures/$uid.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  String _authMessage(String code) => switch (code) {
        'email-already-in-use' =>
          'That email address is already registered to another account.',
        'invalid-email' => 'Please enter a valid email address.',
        'weak-password' => 'Password is too weak (use at least 6 characters).',
        _ => 'Could not create the account. Please try again.',
      };
}

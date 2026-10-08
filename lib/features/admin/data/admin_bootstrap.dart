import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/services/secondary_firebase.dart';
import '../../../shared/models/app_user.dart';

/// Permanent default system-admin credentials.
///
/// These are DEMO credentials for the SE3070 academic project. Change them for
/// any real deployment and keep them out of public builds.
abstract final class DefaultAdmin {
  static const email = 'admin@gmail.com';
  static const password = 'password123';
  static const name = 'System Administrator';
  static const username = 'admin';
}

/// Ensures the permanent default admin account exists. Idempotent and safe to
/// call on every launch — returns immediately once the admin profile is present.
///
/// Creates (or reuses) the Firebase Auth account and writes its Firestore
/// profile via a SECONDARY Firebase app so the primary session is untouched.
/// Never throws: on any failure it simply leaves the admin unseeded.
Future<void> ensureDefaultAdmin() async {
  try {
    final users =
        FirebaseFirestore.instance.collection(FirestoreCollections.users);

    final existing = await users
        .where('email', isEqualTo: DefaultAdmin.email)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await withSecondaryFirebaseApp(
      name: 'wg_admin_bootstrap',
      (app) async {
        final auth = FirebaseAuth.instanceFor(app: app);
        String uid;
        try {
          final cred = await auth.createUserWithEmailAndPassword(
            email: DefaultAdmin.email,
            password: DefaultAdmin.password,
          );
          uid = cred.user!.uid;
        } on FirebaseAuthException catch (e) {
          // Auth account already exists (e.g. profile doc was deleted) — reuse it.
          if (e.code == 'email-already-in-use') {
            final cred = await auth.signInWithEmailAndPassword(
              email: DefaultAdmin.email,
              password: DefaultAdmin.password,
            );
            uid = cred.user!.uid;
          } else {
            rethrow;
          }
        }

        const admin = AppUser(
          id: '', // replaced below with the real uid
          name: DefaultAdmin.name,
          username: DefaultAdmin.username,
          email: DefaultAdmin.email,
          role: UserRole.admin,
          parkId: '',
          isAvailable: false,
          isActive: true,
        );
        await users.doc(uid).set(admin.copyWith(id: uid).toMap());
        await auth.signOut();
      },
    );
  } catch (_) {
    // Leave admin unseeded; login/admin features degrade gracefully.
  }
}

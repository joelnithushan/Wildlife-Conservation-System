import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/services/secondary_firebase.dart';
import '../../../shared/demo/demo_data.dart';
import '../../../shared/models/app_user.dart';
import '../domain/username_generator.dart';

/// A demo staff member to seed, with the details the admin would normally enter.
class _DemoStaff {
  const _DemoStaff({
    required this.fullName,
    required this.email,
    required this.role,
    required this.mobile,
    required this.personalMobile,
    required this.nic,
    required this.gender,
    required this.dob,
  });

  final String fullName;
  final String email;
  final UserRole role;
  final String mobile;
  final String personalMobile;
  final String nic;
  final Gender gender;
  final DateTime dob;
}

/// Shared demo password for the seeded staff accounts (academic project only).
const _demoPassword = 'password123';

/// Canonical demo staff (aligned with AGENTS.md §16/§43). Seeding these gives
/// the admin dashboard real content on first run and lets each role sign in
/// with email OR the generated username to demo the role-based flows.
final _demoStaff = <_DemoStaff>[
  _DemoStaff(
    fullName: 'Sunil Bandara',
    email: 'manager@wildguard.lk',
    role: UserRole.parkManager,
    mobile: '0770000001',
    personalMobile: '0710000001',
    nic: '198512345671',
    gender: Gender.male,
    dob: DateTime(1985, 4, 12),
  ),
  _DemoStaff(
    fullName: 'Kumar Perera',
    email: 'ranger1@wildguard.lk',
    role: UserRole.ranger,
    mobile: '0770000002',
    personalMobile: '0710000002',
    nic: '199212345672',
    gender: Gender.male,
    dob: DateTime(1992, 8, 3),
  ),
  _DemoStaff(
    fullName: 'Ravi Silva',
    email: 'ranger2@wildguard.lk',
    role: UserRole.ranger,
    mobile: '0770000003',
    personalMobile: '0710000003',
    nic: '199412345673',
    gender: Gender.male,
    dob: DateTime(1994, 1, 22),
  ),
  _DemoStaff(
    fullName: 'Nimal Jayasuriya',
    email: 'clo@wildguard.lk',
    role: UserRole.communityLiaisonOfficer,
    mobile: '0770000004',
    personalMobile: '0710000004',
    nic: '199012345674',
    gender: Gender.male,
    dob: DateTime(1990, 11, 9),
  ),
  _DemoStaff(
    fullName: 'Amara Fernando',
    email: 'researcher@wildguard.lk',
    role: UserRole.conservationResearcher,
    mobile: '0770000005',
    personalMobile: '0710000005',
    nic: '199312345675',
    gender: Gender.female,
    dob: DateTime(1993, 6, 18),
  ),
];

/// Ensures the canonical demo staff exist. Idempotent and failure-safe — each
/// account is created only if its email is not already registered, so this can
/// run on every launch. Uses a SECONDARY Firebase app so the signed-in admin
/// session is never disturbed.
Future<void> ensureDemoStaff() async {
  try {
    final users =
        FirebaseFirestore.instance.collection(FirestoreCollections.users);

    // Collect usernames already in use so generated ones stay unique.
    final existingSnap = await users.get();
    final takenUsernames = existingSnap.docs
        .map((d) => (d.data()['username'] as String?) ?? '')
        .where((u) => u.isNotEmpty)
        .toSet();
    final existingEmails = existingSnap.docs
        .map((d) => (d.data()['email'] as String?)?.toLowerCase() ?? '')
        .toSet();

    for (final staff in _demoStaff) {
      if (existingEmails.contains(staff.email.toLowerCase())) continue;

      final username = UsernameGenerator.generate(
        fullName: staff.fullName,
        role: staff.role,
        existingUsernames: takenUsernames,
      );
      takenUsernames.add(username);

      await withSecondaryFirebaseApp(name: 'wg_demo_seed', (app) async {
        final auth = FirebaseAuth.instanceFor(app: app);
        String uid;
        try {
          final cred = await auth.createUserWithEmailAndPassword(
            email: staff.email,
            password: _demoPassword,
          );
          uid = cred.user!.uid;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            // Auth account exists but no profile doc — reuse it.
            final cred = await auth.signInWithEmailAndPassword(
              email: staff.email,
              password: _demoPassword,
            );
            uid = cred.user!.uid;
          } else {
            rethrow;
          }
        }

        final user = AppUser(
          id: uid,
          name: staff.fullName,
          username: username,
          email: staff.email,
          mobileNumber: staff.mobile,
          personalMobileNumber: staff.personalMobile,
          nic: staff.nic,
          gender: staff.gender,
          dateOfBirth: staff.dob,
          photoUrl: '',
          role: staff.role,
          parkId: DemoData.parkId,
        );
        await users.doc(uid).set(user.toMap());
        await auth.signOut();
      });
    }
  } catch (_) {
    // Leave demo staff unseeded on any failure; the app still works.
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../shared/demo/demo_data.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/park.dart';
import '../../../shared/providers/providers.dart';
import '../data/user_admin_service.dart';

/// Admin account-management service. `null` when Firebase is not configured.
final userAdminServiceProvider = Provider<UserAdminService?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  return UserAdminService();
});

/// All staff accounts (excludes admins), for the admin dashboard list.
/// Refreshable with `ref.invalidate(adminUsersProvider)` after create/edit/delete.
final adminUsersProvider = FutureProvider<List<AppUser>>((ref) async {
  final service = ref.watch(userAdminServiceProvider);
  if (service == null) return const [];
  return service.listUsers();
});

/// Parks available for assignment. Reads the `parks` collection and falls back
/// to the canonical demo park (Minneriya) when none exist / Firebase is off.
final parksProvider = FutureProvider<List<Park>>((ref) async {
  if (!ref.watch(firebaseReadyProvider)) return const [DemoData.park];
  try {
    final snap = await FirebaseFirestore.instance
        .collection(FirestoreCollections.parks)
        .get();
    final parks = snap.docs.map((d) => Park.fromMap(d.data())).toList();
    return parks.isEmpty ? const [DemoData.park] : parks;
  } catch (_) {
    return const [DemoData.park];
  }
});

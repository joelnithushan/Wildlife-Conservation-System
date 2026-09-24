import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/firestore_collections.dart';
import '../../../shared/demo/demo_data.dart';

/// Seeds reference/demo data into Firestore for development.
///
/// SAFETY:
/// - Never runs automatically at app startup — call [seedIfMissing] manually
///   (e.g. from a debug action or a one-off script).
/// - Idempotent and non-destructive: each document is written only if it does
///   NOT already exist, so existing data is never overwritten.
/// - Requires Firebase to be configured and initialized.
///
/// Seeds: park, users, patrol routes, risk zones, tracked animals. It does NOT
/// seed patrols/positions/incidents — those are created by field workflows.
class FirestoreDemoSeeder {
  FirestoreDemoSeeder([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Writes demo docs that are missing. Returns the number of docs created.
  Future<int> seedIfMissing() async {
    var created = 0;

    created +=
        await _seed(FirestoreCollections.parks, DemoData.park.id, DemoData.park.toMap());

    for (final user in DemoData.users) {
      created += await _seed(FirestoreCollections.users, user.id, user.toMap());
    }
    for (final route in DemoData.routes) {
      created +=
          await _seed(FirestoreCollections.patrolRoutes, route.id, route.toMap());
    }
    for (final zone in DemoData.riskZones) {
      created += await _seed(FirestoreCollections.riskZones, zone.id, zone.toMap());
    }
    for (final animal in DemoData.trackedAnimals) {
      created +=
          await _seed(FirestoreCollections.trackedAnimals, animal.id, animal.toMap());
    }

    return created;
  }

  Future<int> _seed(String collection, String id, Map<String, dynamic> data) async {
    final ref = _db.collection(collection).doc(id);
    final snapshot = await ref.get();
    if (snapshot.exists) return 0; // never overwrite existing data
    await ref.set(data);
    return 1;
  }
}

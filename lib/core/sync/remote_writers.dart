import 'package:cloud_firestore/cloud_firestore.dart';

import 'sync_service.dart';

/// In-memory [RemoteWriter] for local development / demo runs where Firebase is
/// not configured. Idempotent: keyed by "collection/id", so retrying the same
/// record overwrites rather than duplicating. Also used as a fake in tests.
class InMemoryRemoteWriter implements RemoteWriter {
  final Map<String, Map<String, dynamic>> documents = {};

  int get documentCount => documents.length;

  @override
  Future<void> upsert(
      String collection, String id, Map<String, dynamic> data) async {
    documents['$collection/$id'] = data;
  }
}

/// Production [RemoteWriter] backed by Cloud Firestore. Uses `set(merge:true)` on
/// a document keyed by the record's stable ID for idempotent, retry-safe writes.
/// Requires Firebase to be initialized before use.
class FirestoreRemoteWriter implements RemoteWriter {
  FirestoreRemoteWriter([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> upsert(
      String collection, String id, Map<String, dynamic> data) {
    return _firestore
        .collection(collection)
        .doc(id)
        .set(data, SetOptions(merge: true));
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/exceptions.dart';
import '../../../shared/models/wildlife_risk_alert.dart';
import 'report_read_store.dart';

/// Alerts are unavailable because Firebase is not configured. This is not an
/// error: the report is still generated from local synchronized field records.
class EmptyAlertReadStore implements AlertReadStore {
  const EmptyAlertReadStore();

  @override
  Future<List<WildlifeRiskAlert>> load(String parkId) async => const [];
}

/// Read-only Firestore query for [WildlifeRiskAlert] documents.
class FirestoreAlertReadStore implements AlertReadStore {
  FirestoreAlertReadStore([FirebaseFirestore? firestore])
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  @override
  Future<List<WildlifeRiskAlert>> load(String parkId) async {
    try {
      final db = _firestore ?? FirebaseFirestore.instance;
      final snap = await db
          .collection(FirestoreCollections.wildlifeRiskAlerts)
          .where('parkId', isEqualTo: parkId)
          .get();
      final alerts = <WildlifeRiskAlert>[];
      for (final doc in snap.docs) {
        try {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] ??= doc.id;
          data['createdAt'] = _wireDate(data['createdAt']);
          data['resolvedAt'] = _wireDate(data['resolvedAt']);
          alerts.add(WildlifeRiskAlert.fromMap(data));
        } catch (_) {
          // Skip a partial document rather than failing the whole snapshot.
        }
      }
      return alerts;
    } catch (error) {
      if (error is RepositoryException) rethrow;
      throw const RepositoryException(
        'The data service is unavailable – no new report was created.',
      );
    }
  }

  static Object? _wireDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate().toUtc().toIso8601String();
    return raw;
  }
}

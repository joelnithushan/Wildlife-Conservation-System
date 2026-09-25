import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../../../shared/models/response_assignment.dart';
import '../../../../shared/repositories/conflict_repository.dart';

part 'conflict_repository_impl.g.dart';

class ConflictRepositoryImpl implements ConflictRepository {
  final FirebaseFirestore _firestore;

  ConflictRepositoryImpl(this._firestore);

  @override
  Stream<List<WildlifeRiskAlert>> watchAlerts() {
    return _firestore.collection('wildlife_risk_alerts').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => WildlifeRiskAlert.fromMap(doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> saveAlert(WildlifeRiskAlert alert) async {
    await _firestore
        .collection('wildlife_risk_alerts')
        .doc(alert.id)
        .set(alert.toMap());
  }

  @override
  Future<void> saveAssignment(ResponseAssignment assignment) async {
    await _firestore
        .collection('response_assignments')
        .doc(assignment.id)
        .set(assignment.toMap());
  }
}

@riverpod
ConflictRepository conflictRepository(ConflictRepositoryRef ref) {
  return ConflictRepositoryImpl(FirebaseFirestore.instance);
}

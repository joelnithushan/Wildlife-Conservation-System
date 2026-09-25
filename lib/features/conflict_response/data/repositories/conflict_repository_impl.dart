import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/community_report.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/models/response_assignment.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../../../shared/models/risk_zone.dart';
import '../../../../shared/repositories/conflict_repository.dart';
import '../../../../shared/demo/demo_data.dart';
import '../../domain/usecases/process_location_reading.dart';

part 'conflict_repository_impl.g.dart';

class ConflictRepositoryImpl implements ConflictRepository {
  final FirebaseFirestore _firestore;

  ConflictRepositoryImpl(this._firestore);

  @override
  Future<WildlifeRiskAlert?> processLocationReading(LocationReading reading) async {
    final usecase = ProcessLocationReading(this);
    
    // Fetch active zones. For demo, we just use DemoData.
    final activeZones = DemoData.riskZones;
    
    // Fetch existing open alerts for this animal
    final snapshot = await _firestore
        .collection('wildlife_risk_alerts')
        .where('animalId', isEqualTo: reading.animalId)
        .where('status', isNotEqualTo: AlertStatus.resolved.wire)
        .get();
        
    final existingAlerts = snapshot.docs.map((doc) => WildlifeRiskAlert.fromMap(doc.data())).toList();
    
    return await usecase.call(
      reading: reading,
      activeZones: activeZones,
      existingAlerts: existingAlerts,
    );
  }

  @override
  Future<WildlifeRiskAlert?> processCommunityReport(CommunityReport report) async {
    if (!report.verified) return null;
    
    final usecase = ProcessLocationReading(this);
    final activeZones = DemoData.riskZones;
    
    // Try to find if inside zone
    final reading = LocationReading.create(
      animalId: 'Unknown',
      latitude: report.latitude,
      longitude: report.longitude,
      observedAt: report.createdAt,
      receivedAt: DateTime.now(),
    );
    
    final snapshot = await _firestore
        .collection('wildlife_risk_alerts')
        .where('source', isEqualTo: AlertSource.communityReport.wire)
        .where('status', isNotEqualTo: AlertStatus.resolved.wire)
        .get();
        
    final existingAlerts = snapshot.docs.map((doc) => WildlifeRiskAlert.fromMap(doc.data())).toList();

    return await usecase.call(
      reading: reading,
      activeZones: activeZones,
      existingAlerts: existingAlerts,
      isCommunityReport: true,
      parkId: report.parkId,
    );
  }

  @override
  Future<List<WildlifeRiskAlert>> getAlerts(String parkId) async {
    final snapshot = await _firestore
        .collection('wildlife_risk_alerts')
        .where('parkId', isEqualTo: parkId)
        .get();
    return snapshot.docs.map((doc) => WildlifeRiskAlert.fromMap(doc.data())).toList();
  }

  @override
  Future<WildlifeRiskAlert?> getAlert(String id) async {
    final doc = await _firestore.collection('wildlife_risk_alerts').doc(id).get();
    if (doc.exists) {
      return WildlifeRiskAlert.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<List<AppUser>> getAvailableResponders(String parkId) async {
    // For demo, return the users from demo data who are responders
    return DemoData.users.where((u) => u.role == UserRole.ranger || u.role == UserRole.communityLiaisonOfficer).toList();
  }

  @override
  Future<ResponseAssignment> assignResponder({
    required String alertId,
    required String responderId,
    required String assignedBy,
  }) async {
    final responders = await getAvailableResponders('PARK-MIN');
    final responder = responders.firstWhere((r) => r.id == responderId);
    
    final assignment = ResponseAssignment.create(
      alertId: alertId,
      responderId: responderId,
      responderRole: responder.role == UserRole.ranger ? ResponderRole.ranger : ResponderRole.communityLiaisonOfficer,
      assignedBy: assignedBy,
      assignedAt: DateTime.now(),
    );
    await _firestore.collection('response_assignments').doc(assignment.id).set(assignment.toMap());
    
    // Update alert status
    final alert = await getAlert(alertId);
    if (alert != null) {
      final updatedAlert = alert.copyWith(status: AlertStatus.assigned);
      await _firestore.collection('wildlife_risk_alerts').doc(alertId).set(updatedAlert.toMap());
    }
    
    // Simulate notification delivery
    final deliveredAssignment = assignment.copyWith(
      deliveryState: DeliveryState.delivered,
      deliveredAt: DateTime.now(),
    );
    await _firestore.collection('response_assignments').doc(assignment.id).set(deliveredAssignment.toMap());
    
    return deliveredAssignment;
  }
  
  @override
  Future<ResponseAssignment> acknowledgeAssignment(String assignmentId) async {
    final doc = await _firestore.collection('response_assignments').doc(assignmentId).get();
    final assignment = ResponseAssignment.fromMap(doc.data()!);
    final updated = assignment.copyWith(acknowledgedAt: DateTime.now());
    await _firestore.collection('response_assignments').doc(assignmentId).set(updated.toMap());
    
    final alert = await getAlert(assignment.alertId);
    if (alert != null) {
      final updatedAlert = alert.copyWith(status: AlertStatus.acknowledged);
      await _firestore.collection('wildlife_risk_alerts').doc(alert.id).set(updatedAlert.toMap());
    }
    return updated;
  }
  
  @override
  Future<ResponseAssignment> startResponse(String assignmentId) async {
    final doc = await _firestore.collection('response_assignments').doc(assignmentId).get();
    final assignment = ResponseAssignment.fromMap(doc.data()!);
    final updated = assignment.copyWith(startedAt: DateTime.now());
    await _firestore.collection('response_assignments').doc(assignmentId).set(updated.toMap());
    
    final alert = await getAlert(assignment.alertId);
    if (alert != null) {
      final updatedAlert = alert.copyWith(status: AlertStatus.responseInProgress);
      await _firestore.collection('wildlife_risk_alerts').doc(alert.id).set(updatedAlert.toMap());
    }
    return updated;
  }
  
  @override
  Future<ResponseAssignment> updateResponseStatus({
    required String assignmentId,
    required String statusNote,
  }) async {
    final doc = await _firestore.collection('response_assignments').doc(assignmentId).get();
    final assignment = ResponseAssignment.fromMap(doc.data()!);
    final updated = assignment.copyWith(statusNote: statusNote);
    await _firestore.collection('response_assignments').doc(assignmentId).set(updated.toMap());
    return updated;
  }
  
  @override
  Future<ResponseAssignment> recordOutcome({
    required String assignmentId,
    required String outcome,
  }) async {
    final doc = await _firestore.collection('response_assignments').doc(assignmentId).get();
    final assignment = ResponseAssignment.fromMap(doc.data()!);
    final updated = assignment.copyWith(outcome: outcome, completedAt: DateTime.now());
    await _firestore.collection('response_assignments').doc(assignmentId).set(updated.toMap());
    return updated;
  }
  
  @override
  Future<WildlifeRiskAlert> resolveAlert(String alertId) async {
    final alert = await getAlert(alertId);
    if (alert == null) throw Exception('Alert not found');
    final updatedAlert = alert.copyWith(status: AlertStatus.resolved, resolvedAt: DateTime.now());
    await _firestore.collection('wildlife_risk_alerts').doc(alertId).set(updatedAlert.toMap());
    return updatedAlert;
  }
  
  // Custom helper
  Future<void> saveAlert(WildlifeRiskAlert alert) async {
    await _firestore.collection('wildlife_risk_alerts').doc(alert.id).set(alert.toMap());
  }
}

@riverpod
ConflictRepository conflictRepository(ConflictRepositoryRef ref) {
  return ConflictRepositoryImpl(FirebaseFirestore.instance);
}

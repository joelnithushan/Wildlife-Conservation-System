import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/community_report.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/models/response_assignment.dart';
import '../../../../shared/models/risk_zone.dart';
import '../../../../shared/models/tracked_animal.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../../../shared/repositories/conflict_repository.dart';
import '../../domain/alert_rules.dart';
import '../../domain/conflict_config.dart';
import '../../domain/notification_service.dart';
import '../../domain/reading_validation.dart';
import '../../domain/usecases/process_location_reading.dart';

class FirestoreConflictRepository implements ConflictRepository {
  FirestoreConflictRepository({
    required FirebaseFirestore firestore,
    required NotificationService notificationService,
    ConflictConfig config = ConflictConfig.defaults,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _notifications = notificationService,
        _config = config,
        _now = now ?? DateTime.now {
    _processor = ProcessLocationReading(config: _config);
  }

  final FirebaseFirestore _firestore;
  final NotificationService _notifications;
  final ConflictConfig _config;
  final DateTime Function() _now;
  late final ProcessLocationReading _processor;
  
  final Set<String> _seenReadingIds = {};

  // --- Triggers -------------------------------------------------------------

  @override
  Future<WildlifeRiskAlert?> processLocationReading(
    LocationReading reading,
  ) async {
    final activeZones = await _getAllRiskZones();
    final existingAlerts = await _getAllAlerts();
    
    final result = _processor.call(
      reading: reading,
      activeZones: activeZones,
      existingAlerts: existingAlerts,
      now: _now(),
      seenReadingIds: _seenReadingIds,
    );

    if (result.outcome == ProcessOutcome.rejected) {
      throw ConflictException(result.rejection.message);
    }

    _seenReadingIds.add(reading.id);
    
    // Save the location reading.
    await _firestore
        .collection(FirestoreCollections.locationReadings)
        .doc(reading.id)
        .set(reading.toMap(), SetOptions(merge: true));

    if (result.alert != null) {
      await _firestore
          .collection(FirestoreCollections.wildlifeRiskAlerts)
          .doc(result.alert!.id)
          .set(result.alert!.toMap(), SetOptions(merge: true));
    }
    
    return result.alert;
  }

  @override
  Future<WildlifeRiskAlert?> processCommunityReport(
    CommunityReport report,
  ) async {
    if (!report.verified) return null;
    
    final activeZones = await _getAllRiskZones();
    final existingAlerts = await _getAllAlerts();

    final result = _processor.fromCommunityPoint(
      parkId: report.parkId,
      latitude: report.latitude,
      longitude: report.longitude,
      activeZones: activeZones,
      existingAlerts: existingAlerts,
      now: _now(),
    );
    
    if (result.outcome == ProcessOutcome.rejected) {
      throw ConflictException(result.rejection.message);
    }
    
    if (result.alert != null) {
      await _firestore
          .collection(FirestoreCollections.wildlifeRiskAlerts)
          .doc(result.alert!.id)
          .set(result.alert!.toMap(), SetOptions(merge: true));
    }
    return result.alert;
  }

  // --- Reference/read data --------------------------------------------------

  Future<List<RiskZone>> _getAllRiskZones() async {
    final snap = await _firestore.collection(FirestoreCollections.riskZones).get();
    return snap.docs.map((d) => RiskZone.fromMap(d.data())).toList();
  }
  
  Future<List<WildlifeRiskAlert>> _getAllAlerts() async {
    final snap = await _firestore.collection(FirestoreCollections.wildlifeRiskAlerts).get();
    return snap.docs.map((d) => WildlifeRiskAlert.fromMap(d.data())).toList();
  }

  @override
  Future<List<WildlifeRiskAlert>> getAlerts(String parkId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.wildlifeRiskAlerts)
        .where('parkId', isEqualTo: parkId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => WildlifeRiskAlert.fromMap(d.data())).toList();
  }

  @override
  Future<WildlifeRiskAlert?> getAlert(String id) async {
    final doc = await _firestore.collection(FirestoreCollections.wildlifeRiskAlerts).doc(id).get();
    if (!doc.exists) return null;
    return WildlifeRiskAlert.fromMap(doc.data()!);
  }

  @override
  Future<List<RiskZone>> getRiskZones(String parkId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.riskZones)
        .where('parkId', isEqualTo: parkId)
        .get();
    return snap.docs.map((d) => RiskZone.fromMap(d.data())).toList();
  }

  @override
  Future<List<TrackedAnimal>> getTrackedAnimals() async {
    final snap = await _firestore.collection(FirestoreCollections.trackedAnimals).get();
    return snap.docs.map((d) => TrackedAnimal.fromMap(d.data())).toList();
  }

  // --- Community reports ------------------------------------------------------

  @override
  Future<List<CommunityReport>> getCommunityReports(String parkId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.communityReports)
        .where('parkId', isEqualTo: parkId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => CommunityReport.fromMap(d.data())).toList();
  }

  @override
  Future<CommunityReport> verifyCommunityReport({
    required String reportId,
    required String verifiedBy,
  }) async {
    final docRef = _firestore.collection(FirestoreCollections.communityReports).doc(reportId);
    
    return await _firestore.runTransaction((tx) async {
      final doc = await tx.get(docRef);
      if (!doc.exists) throw const ConflictException('Community report not found.');
      
      final report = CommunityReport.fromMap(doc.data()!);
      final updated = report.copyWith(verified: true, verifiedBy: verifiedBy);
      tx.set(docRef, updated.toMap(), SetOptions(merge: true));
      return updated;
    });
  }

  // --- Responders & assignments ---------------------------------------------

  @override
  Future<List<AppUser>> getAvailableResponders(String parkId) async {
    // `isResponder` is a role-derived getter on AppUser, not a stored field, so
    // it can't be queried directly. Filter by the stored fields (parkId +
    // isAvailable) and apply the responder-role predicate client-side.
    final snap = await _firestore
        .collection(FirestoreCollections.users)
        .where('parkId', isEqualTo: parkId)
        .where('isAvailable', isEqualTo: true)
        .get();
    return snap.docs
        .map((d) => AppUser.fromMap(d.data()))
        .where((u) => u.isResponder)
        .toList();
  }

  @override
  Future<List<ResponseAssignment>> getAssignmentsForAlert(String alertId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.responseAssignments)
        .where('alertId', isEqualTo: alertId)
        .orderBy('assignedAt', descending: false)
        .get();
    return snap.docs.map((d) => ResponseAssignment.fromMap(d.data())).toList();
  }

  @override
  Future<ResponseAssignment?> getActiveAssignment(String alertId) async {
    final list = await getAssignmentsForAlert(alertId);
    return list.isEmpty ? null : list.last;
  }

  @override
  Future<ResponseAssignment?> getAssignment(String assignmentId) async {
    final doc = await _firestore.collection(FirestoreCollections.responseAssignments).doc(assignmentId).get();
    if (!doc.exists) return null;
    return ResponseAssignment.fromMap(doc.data()!);
  }

  @override
  Future<ResponseAssignment> assignResponder({
    required String alertId,
    required String responderId,
    required String assignedBy,
  }) async {
    final alertRef = _firestore.collection(FirestoreCollections.wildlifeRiskAlerts).doc(alertId);
    
    // Using a transaction to ensure atomic read/write on assignments and alert state
    final assignment = await _firestore.runTransaction((tx) async {
      final alertDoc = await tx.get(alertRef);
      if (!alertDoc.exists) throw const ConflictException('Alert not found.');
      final alert = WildlifeRiskAlert.fromMap(alertDoc.data()!);
      
      if (alert.status == AlertStatus.resolved) {
        throw const ConflictException('Cannot assign: alert is resolved.');
      }
      
      if (alert.status == AlertStatus.acknowledged ||
          alert.status == AlertStatus.responseInProgress) {
        throw const ConflictException('Alert already has an active responder in progress.');
      }
      
      final userDoc = await tx.get(_firestore.collection(FirestoreCollections.users).doc(responderId));
      if (!userDoc.exists) throw const ConflictException('Responder not found.');
      final responder = AppUser.fromMap(userDoc.data()!);
      if (!responder.isResponder || !responder.isAvailable) {
        throw const ConflictException('Assignment conflict: responder is no longer available.');
      }
      
      final assignment = ResponseAssignment.create(
        alertId: alertId,
        responderId: responderId,
        responderRole: responder.role == UserRole.ranger
            ? ResponderRole.ranger
            : ResponderRole.communityLiaisonOfficer,
        assignedBy: assignedBy,
        assignedAt: _now(),
      );
      
      final assignmentRef = _firestore.collection(FirestoreCollections.responseAssignments).doc(assignment.id);
      tx.set(assignmentRef, assignment.toMap());
      
      if (alert.status == AlertStatus.newAlert) {
        AlertRules.assertTransition(alert.status, AlertStatus.assigned);
        tx.update(alertRef, {'status': AlertStatus.assigned.wire});
      }
      
      return assignment;
    });
    
    final result = await _notifications.notifyAssignment(
      assignmentId: assignment.id,
      responderId: responderId,
      title: 'New response assignment',
      body: 'You have been assigned to alert ${assignment.alertId}.',
    );
    
    final delivered = assignment.copyWith(
      deliveryState: result.state,
      deliveredAt: result.isDelivered ? _now() : null,
    );
    
    await _firestore
        .collection(FirestoreCollections.responseAssignments)
        .doc(assignment.id)
        .set(delivered.toMap(), SetOptions(merge: true));
        
    return delivered;
  }

  @override
  Future<ResponseAssignment> acknowledgeAssignment({
    required String assignmentId,
    required String responderId,
  }) async {
    final assignmentRef = _firestore.collection(FirestoreCollections.responseAssignments).doc(assignmentId);
    
    return await _firestore.runTransaction((tx) async {
      final doc = await tx.get(assignmentRef);
      if (!doc.exists) throw const ConflictException('Assignment not found.');
      final assignment = ResponseAssignment.fromMap(doc.data()!);
      
      if (assignment.responderId != responderId) {
        throw const ConflictException('Only the assigned responder can acknowledge this assignment.');
      }
      if (assignment.acknowledgedAt != null) {
        throw const ConflictException('Assignment already acknowledged.');
      }
      
      final alertRef = _firestore.collection(FirestoreCollections.wildlifeRiskAlerts).doc(assignment.alertId);
      final alertDoc = await tx.get(alertRef);
      if (!alertDoc.exists) throw const ConflictException('Alert not found.');
      
      final alert = WildlifeRiskAlert.fromMap(alertDoc.data()!);
      AlertRules.assertTransition(alert.status, AlertStatus.acknowledged);
      
      final updated = assignment.copyWith(acknowledgedAt: _now());
      tx.set(assignmentRef, updated.toMap(), SetOptions(merge: true));
      tx.update(alertRef, {'status': AlertStatus.acknowledged.wire});
      
      return updated;
    });
  }

  @override
  Future<ResponseAssignment> startResponse(String assignmentId) async {
    final assignmentRef = _firestore.collection(FirestoreCollections.responseAssignments).doc(assignmentId);
    
    return await _firestore.runTransaction((tx) async {
      final doc = await tx.get(assignmentRef);
      if (!doc.exists) throw const ConflictException('Assignment not found.');
      final assignment = ResponseAssignment.fromMap(doc.data()!);
      
      if (assignment.acknowledgedAt == null) {
        throw const ConflictException('Cannot start response before acknowledgement.');
      }
      
      final alertRef = _firestore.collection(FirestoreCollections.wildlifeRiskAlerts).doc(assignment.alertId);
      final alertDoc = await tx.get(alertRef);
      if (!alertDoc.exists) throw const ConflictException('Alert not found.');
      
      final alert = WildlifeRiskAlert.fromMap(alertDoc.data()!);
      AlertRules.assertTransition(alert.status, AlertStatus.responseInProgress);
      
      final updated = assignment.copyWith(startedAt: _now());
      tx.set(assignmentRef, updated.toMap(), SetOptions(merge: true));
      tx.update(alertRef, {'status': AlertStatus.responseInProgress.wire});
      
      return updated;
    });
  }

  @override
  Future<ResponseAssignment> updateResponseStatus({
    required String assignmentId,
    required String statusNote,
  }) async {
    final assignmentRef = _firestore.collection(FirestoreCollections.responseAssignments).doc(assignmentId);
    return await _firestore.runTransaction((tx) async {
      final doc = await tx.get(assignmentRef);
      if (!doc.exists) throw const ConflictException('Assignment not found.');
      final assignment = ResponseAssignment.fromMap(doc.data()!);
      
      if (assignment.startedAt == null) {
        throw const ConflictException('Cannot record a status note before the response starts.');
      }
      
      final updated = assignment.copyWith(statusNote: statusNote);
      tx.set(assignmentRef, updated.toMap(), SetOptions(merge: true));
      return updated;
    });
  }

  @override
  Future<ResponseAssignment> recordOutcome({
    required String assignmentId,
    required String outcome,
  }) async {
    if (outcome.trim().isEmpty) {
      throw const ConflictException('Outcome cannot be empty.');
    }
    
    final assignmentRef = _firestore.collection(FirestoreCollections.responseAssignments).doc(assignmentId);
    return await _firestore.runTransaction((tx) async {
      final doc = await tx.get(assignmentRef);
      if (!doc.exists) throw const ConflictException('Assignment not found.');
      final assignment = ResponseAssignment.fromMap(doc.data()!);
      
      if (assignment.startedAt == null) {
        throw const ConflictException('Cannot record an outcome before the response starts.');
      }
      
      final updated = assignment.copyWith(
        outcome: outcome,
        completedAt: _now(),
      );
      tx.set(assignmentRef, updated.toMap(), SetOptions(merge: true));
      return updated;
    });
  }

  @override
  Future<WildlifeRiskAlert> resolveAlert(String alertId) async {
    final alertRef = _firestore.collection(FirestoreCollections.wildlifeRiskAlerts).doc(alertId);
    
    return await _firestore.runTransaction((tx) async {
      final alertDoc = await tx.get(alertRef);
      if (!alertDoc.exists) throw const ConflictException('Alert not found.');
      
      final alert = WildlifeRiskAlert.fromMap(alertDoc.data()!);
      
      final assignmentsSnap = await _firestore
        .collection(FirestoreCollections.responseAssignments)
        .where('alertId', isEqualTo: alertId)
        .orderBy('assignedAt', descending: false)
        .get();
        
      final assignments = assignmentsSnap.docs.map((d) => ResponseAssignment.fromMap(d.data())).toList();
      
      AlertRules.assertResolvable(alert, assignments);
      
      final resolved = alert.copyWith(
        status: AlertStatus.resolved,
        resolvedAt: _now(),
      );
      
      tx.set(alertRef, resolved.toMap(), SetOptions(merge: true));
      return resolved;
    });
  }
}

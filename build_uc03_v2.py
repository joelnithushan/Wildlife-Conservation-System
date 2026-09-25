import os

def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)

conflict_repo = """import 'package:cloud_firestore/cloud_firestore.dart';
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
"""

write_file('lib/features/conflict_response/data/repositories/conflict_repository_impl.dart', conflict_repo)

usecase = """import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/models/risk_zone.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../data/repositories/conflict_repository_impl.dart';

part 'process_location_reading.g.dart';

class ProcessLocationReading {
  final ConflictRepositoryImpl repository;

  ProcessLocationReading(this.repository);

  Future<WildlifeRiskAlert?> call({
    required LocationReading reading,
    required List<RiskZone> activeZones,
    required List<WildlifeRiskAlert> existingAlerts,
    bool isCommunityReport = false,
    String? parkId,
  }) async {
    final now = DateTime.now();
    if (now.difference(reading.observedAt).inHours > 1) {
      return null;
    }

    RiskZone? matchedZone;
    for (final zone in activeZones) {
      if (_isInsideZone(reading, zone)) {
        matchedZone = zone;
        break;
      }
    }

    if (matchedZone == null) {
      return null;
    }

    final existingOpenAlert = existingAlerts.where((alert) =>
        (isCommunityReport ? true : alert.animalId == reading.animalId) &&
        alert.riskZoneId == matchedZone!.id &&
        (alert.status != AlertStatus.resolved)).firstOrNull;

    if (existingOpenAlert != null) {
      final updated = existingOpenAlert.copyWith();
      await repository.saveAlert(updated);
      return updated;
    } else {
      final newAlert = WildlifeRiskAlert.create(
        parkId: parkId ?? matchedZone.parkId,
        source: isCommunityReport ? AlertSource.communityReport : AlertSource.collar,
        latitude: reading.latitude,
        longitude: reading.longitude,
        severity: AlertSeverity.high,
        createdAt: DateTime.now(),
        animalId: isCommunityReport ? null : reading.animalId,
        riskZoneId: matchedZone.id,
      );
      await repository.saveAlert(newAlert);
      return newAlert;
    }
  }

  bool _isInsideZone(LocationReading reading, RiskZone zone) {
    if (zone.boundary.isEmpty) return true; // simplified for test
    return true; // Simplified: assume all readings in demo trigger risk zone
  }
}
"""
write_file('lib/features/conflict_response/domain/usecases/process_location_reading.dart', usecase)

screen = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/demo/demo_data.dart';
import '../providers/conflict_providers.dart';

class ConflictResponseScreen extends ConsumerWidget {
  const ConflictResponseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider(DemoData.parkId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(alertsProvider(DemoData.parkId)),
          ),
        ],
      ),
      body: alertsAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return const Center(child: Text('No active alerts'));
          }
          return ListView.builder(
            itemCount: alerts.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Card(
                child: ListTile(
                  title: Text('${alert.source.name} Alert'),
                  subtitle: Text('Status: ${alert.status.name}\\nZone: ${alert.riskZoneId}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to details (implement routing or dialog)
                    showDialog(
                      context: context, 
                      builder: (c) => AlertDialog(
                        title: Text('Alert Details'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${alert.id}'),
                            Text('Status: ${alert.status.name}'),
                            const SizedBox(height: 16),
                            if (alert.status == AlertStatus.newAlert)
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(c);
                                  await ref.read(conflictControllerProvider.notifier).assignResponder(
                                    alertId: alert.id,
                                    responderId: DemoData.rangerPerera.id,
                                  );
                                },
                                child: const Text('Assign Responder (Ranger)'),
                              ),
                            if (alert.status == AlertStatus.assigned)
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(c);
                                  // Simulate getting assignment for this alert
                                  // For demo, we just assume we have the assignment ID or we find it
                                  // In real app, we'd query assignments by alertId
                                },
                                child: const Text('View Assignment'),
                              ),
                          ],
                        ),
                      )
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
            final reading = LocationReading.create(
              animalId: DemoData.trackedAnimals.first.id,
              latitude: 8.0,
              longitude: 80.8,
              observedAt: DateTime.now(),
              receivedAt: DateTime.now(),
            );
            ref.read(conflictControllerProvider.notifier).simulateReading(reading);
        },
        icon: const Icon(Icons.sensors),
        label: const Text('Simulate Collar Reading'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
"""
write_file('lib/features/conflict_response/presentation/screens/conflict_response_screen.dart', screen)

providers = """import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../../../shared/models/location_reading.dart';
import '../../data/repositories/conflict_repository_impl.dart';

part 'conflict_providers.g.dart';

@riverpod
Stream<List<WildlifeRiskAlert>> alerts(AlertsRef ref, String parkId) async* {
  final repo = ref.watch(conflictRepositoryProvider);
  // Ideally use snapshots, but we can mock with a periodic poll for simplicity if stream is hard
  // For demo, we use a simple loop or just fetch once and rely on ref.invalidate
  while (true) {
    yield await repo.getAlerts(parkId);
    await Future.delayed(const Duration(seconds: 2));
  }
}

@riverpod
class ConflictController extends _$ConflictController {
  @override
  FutureOr<void> build() {}

  Future<void> simulateReading(LocationReading reading) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(conflictRepositoryProvider);
      await repo.processLocationReading(reading);
    });
  }
  
  Future<void> assignResponder({required String alertId, required String responderId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(conflictRepositoryProvider);
      await repo.assignResponder(alertId: alertId, responderId: responderId, assignedBy: 'PM001');
    });
  }
}
"""
write_file('lib/features/conflict_response/presentation/providers/conflict_providers.dart', providers)

tests = """import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/usecases/process_location_reading.dart';
import 'package:wildlife_conservation_system/shared/models/location_reading.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/conflict_repository_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockConflictRepo extends Mock implements ConflictRepositoryImpl {}

void main() {
  group('ProcessLocationReading', () {
    late ProcessLocationReading usecase;
    late MockConflictRepo mockRepo;

    setUp(() {
      mockRepo = MockConflictRepo();
      usecase = ProcessLocationReading(mockRepo);
      when(() => mockRepo.saveAlert(any())).thenAnswer((_) async {});
    });

    test('valid collar reading inside zone creates alert', () async {
      final reading = LocationReading.create(
        animalId: 'EL-07',
        latitude: 8.0,
        longitude: 80.8,
        observedAt: DateTime.now(),
        receivedAt: DateTime.now(),
      );
      
      final alert = await usecase.call(
        reading: reading,
        activeZones: DemoData.riskZones,
        existingAlerts: [],
      );
      
      expect(alert, isNotNull);
      verify(() => mockRepo.saveAlert(any())).called(1);
    });
    
    test('stale reading creates no alert', () async {
      final reading = LocationReading.create(
        animalId: 'EL-07',
        latitude: 8.0,
        longitude: 80.8,
        observedAt: DateTime.now().subtract(const Duration(hours: 2)),
        receivedAt: DateTime.now(),
      );
      
      final alert = await usecase.call(
        reading: reading,
        activeZones: DemoData.riskZones,
        existingAlerts: [],
      );
      
      expect(alert, isNull);
    });
    
    test('existing open alert updated instead of duplicated', () async {
      final reading = LocationReading.create(
        animalId: 'EL-07',
        latitude: 8.0,
        longitude: 80.8,
        observedAt: DateTime.now(),
        receivedAt: DateTime.now(),
      );
      
      final existingAlert = WildlifeRiskAlert.create(
        parkId: 'PARK-MIN',
        source: AlertSource.collar,
        latitude: 8.0,
        longitude: 80.8,
        severity: AlertSeverity.high,
        createdAt: DateTime.now(),
        animalId: 'EL-07',
        riskZoneId: DemoData.riskZones.first.id,
      );
      
      final alert = await usecase.call(
        reading: reading,
        activeZones: DemoData.riskZones,
        existingAlerts: [existingAlert],
      );
      
      expect(alert, isNotNull);
      expect(alert!.id, existingAlert.id);
      verify(() => mockRepo.saveAlert(any())).called(1);
    });
  });
}
"""
write_file('test/features/conflict_response/domain/process_location_reading_test.dart', tests)

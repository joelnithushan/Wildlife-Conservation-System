import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/firestore_conflict_repository.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/notification_service.dart';
import 'package:wildlife_conservation_system/shared/models/community_report.dart';
import 'package:wildlife_conservation_system/shared/models/location_reading.dart';
import 'package:wildlife_conservation_system/shared/models/response_assignment.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/providers/conflict_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockNotificationService extends Mock implements NotificationService {}
class MockTransaction extends Mock implements Transaction {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

void main() {
  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
  });

  group('UC03 Persistence Tests', () {
    test('1. LocationReading serialized correctly', () {
      final now = DateTime.now();
      final reading = LocationReading.create(
        animalId: 'a1',
        latitude: 10.0,
        longitude: 20.0,
        observedAt: now,
        receivedAt: now,
      );
      final map = reading.toMap();
      expect(map['id'], reading.id);
      expect(map['animalId'], 'a1');
      
      final restored = LocationReading.fromMap(map);
      expect(restored, reading);
    });

    test('2. CommunityReport persisted with stable ID and serializes', () {
      final now = DateTime.now();
      final report = CommunityReport.create(
        parkId: 'p1',
        description: 'test',
        latitude: 10.0,
        longitude: 20.0,
        createdAt: now,
      );
      final map = report.toMap();
      final restored = CommunityReport.fromMap(map);
      expect(restored.id, report.id);
      expect(restored, report);
    });

    test('4. new WildlifeRiskAlert persisted serializes', () {
      final now = DateTime.now();
      final alert = WildlifeRiskAlert.create(
        parkId: 'p1',
        source: AlertSource.collar,
        latitude: 1.0,
        longitude: 1.0,
        severity: AlertSeverity.high,
        createdAt: now,
      );
      final map = alert.toMap();
      expect(WildlifeRiskAlert.fromMap(map), alert);
    });

    test('6. ResponseAssignment persisted serializes', () {
      final now = DateTime.now();
      final assignment = ResponseAssignment.create(
        alertId: 'al1',
        responderId: 'r1',
        responderRole: ResponderRole.ranger,
        assignedBy: 'm1',
        assignedAt: now,
      );
      final map = assignment.toMap();
      expect(ResponseAssignment.fromMap(map), assignment);
    });
    
    test('14. production provider selects Firestore implementation', () {
      final container = ProviderContainer();
      final repo = container.read(conflictRepositoryProvider);
      expect(repo, isA<FirestoreConflictRepository>());
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/drift_conflict_repository.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/in_memory_conflict_repository.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/providers/conflict_providers.dart';
import 'package:wildlife_conservation_system/shared/models/community_report.dart';
import 'package:wildlife_conservation_system/shared/models/location_reading.dart';
import 'package:wildlife_conservation_system/shared/models/response_assignment.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';

void main() {
  // Dates round-trip through wire as UTC (dateToWire/dateFromWire), so tests use
  // UTC instants to keep value-equality deterministic across serialization.
  final ts = DateTime.utc(2026, 9, 30, 12, 0, 0);

  group('UC03 persistence serialization', () {
    test('1. LocationReading round-trips with stable id', () {
      final reading = LocationReading.create(
        animalId: 'a1',
        latitude: 10.0,
        longitude: 20.0,
        observedAt: ts,
        receivedAt: ts,
      );
      final map = reading.toMap();
      expect(map['id'], reading.id);
      expect(map['animalId'], 'a1');
      expect(LocationReading.fromMap(map), reading);
    });

    test('2. CommunityReport round-trips with stable id', () {
      final report = CommunityReport.create(
        parkId: 'p1',
        description: 'test',
        latitude: 10.0,
        longitude: 20.0,
        createdAt: ts,
      );
      final restored = CommunityReport.fromMap(report.toMap());
      expect(restored.id, report.id);
      expect(restored, report);
    });

    test('4. WildlifeRiskAlert round-trips', () {
      final alert = WildlifeRiskAlert.create(
        parkId: 'p1',
        source: AlertSource.collar,
        latitude: 1.0,
        longitude: 1.0,
        severity: AlertSeverity.high,
        createdAt: ts,
      );
      expect(WildlifeRiskAlert.fromMap(alert.toMap()), alert);
    });

    test('6. ResponseAssignment round-trips', () {
      final assignment = ResponseAssignment.create(
        alertId: 'al1',
        responderId: 'r1',
        responderRole: ResponderRole.ranger,
        assignedBy: 'm1',
        assignedAt: ts,
      );
      expect(ResponseAssignment.fromMap(assignment.toMap()), assignment);
    });
  });

  group('UC03 repository wiring', () {
    test('14. falls back to Drift SQLite repository when Firebase not ready', () {
      // firebaseReadyProvider defaults to false — the provider must return the
      // Drift SQLite persistent repository so UC03 survives app restarts like UC01/UC02.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(conflictRepositoryProvider);
      expect(repo, isA<DriftConflictRepository>());
    });

    test('15. in-memory fallback repository is usable and seeds demo alerts',
        () async {
      final repo = InMemoryConflictRepository();
      final alerts = await repo.getAlerts('PARK-MIN');
      expect(alerts, isNotEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/datasources/conflict_local_data_source.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/notification/simulated_notification_service.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/drift_conflict_repository.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/conflict_config.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';
import 'package:wildlife_conservation_system/shared/models/community_report.dart';
import 'package:wildlife_conservation_system/shared/models/location_reading.dart';
import 'package:wildlife_conservation_system/shared/models/response_assignment.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';

import '../../../patrol/helpers.dart';

void main() {
  group('DriftConflictRepository persistence and lifecycle', () {
    test('survives app restart: data persists across repository re-instantiation',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final fixedTime = DateTime.utc(2026, 9, 25, 10, 0, 0);
      final localDataSource = ConflictLocalDataSource(db);

      // Session 1: Create repository and insert items
      final repo1 = DriftConflictRepository(
        localDataSource: localDataSource,
        notificationService: SimulatedNotificationService(),
        now: () => fixedTime,
      );

      final reading = LocationReading.create(
        animalId: 'EL-07',
        latitude: 8.04,
        longitude: 80.91,
        observedAt: fixedTime,
        receivedAt: fixedTime,
      );
      await localDataSource.saveReading(reading);

      final alert = WildlifeRiskAlert.create(
        parkId: 'PARK-MIN',
        source: AlertSource.collar,
        latitude: 8.04,
        longitude: 80.91,
        severity: AlertSeverity.high,
        createdAt: fixedTime,
        animalId: 'EL-07',
      );
      await localDataSource.upsertAlert(alert);

      final communityReport = CommunityReport.create(
        parkId: 'PARK-MIN',
        description: 'Herd near main paddy canal',
        latitude: 8.055,
        longitude: 80.885,
        createdAt: fixedTime,
        channel: 'SMS',
      );
      await repo1.submitCommunityReport(communityReport);

      final assignment = ResponseAssignment.create(
        alertId: alert.id,
        responderId: 'U002',
        responderRole: ResponderRole.ranger,
        assignedBy: 'U001',
        assignedAt: fixedTime,
      );
      await localDataSource.upsertAssignment(assignment);

      // Verify Session 1 sees data
      final alertsSession1 = await repo1.getAlerts('PARK-MIN');
      expect(alertsSession1.any((a) => a.id == alert.id), isTrue);

      // Simulating App Restart: instantiate fresh repository instance on same database
      final repo2 = DriftConflictRepository(
        localDataSource: ConflictLocalDataSource(db),
        notificationService: SimulatedNotificationService(),
        now: () => fixedTime,
      );

      // Verify Session 2 loads persisted data intact
      final alertsSession2 = await repo2.getAlerts('PARK-MIN');
      expect(alertsSession2.any((a) => a.id == alert.id), isTrue);

      final loadedAlert = await repo2.getAlert(alert.id);
      expect(loadedAlert, isNotNull);
      expect(loadedAlert!.animalId, 'EL-07');
      expect(loadedAlert.severity, AlertSeverity.high);

      final loadedAssignment = await repo2.getActiveAssignment(alert.id);
      expect(loadedAssignment, isNotNull);
      expect(loadedAssignment!.responderId, 'U002');
      expect(loadedAssignment.responderRole, ResponderRole.ranger);

      final communityReportsSession2 = await repo2.getCommunityReports('PARK-MIN');
      final foundReport = communityReportsSession2.firstWhere((r) => r.id == communityReport.id);
      expect(foundReport.channel, 'SMS');
      expect(foundReport.description, 'Herd near main paddy canal');

      final readingsSession2 = await localDataSource.getAllReadings();
      expect(readingsSession2.any((r) => r.id == reading.id), isTrue);
    });

    test('creates AlertStatusChange record on every state transition', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      var currentTime = DateTime.utc(2026, 9, 25, 10, 0, 0);
      const responder = AppUser(
        id: 'U002',
        name: 'Ranger Silva',
        email: 'silva@park.lk',
        role: UserRole.ranger,
        parkId: 'PARK-MIN',
      );

      final localDataSource = ConflictLocalDataSource(db);
      final repo = DriftConflictRepository(
        localDataSource: localDataSource,
        notificationService: SimulatedNotificationService(),
        responders: [responder],
        now: () => currentTime,
      );

      final alert = WildlifeRiskAlert.create(
        parkId: 'PARK-MIN',
        source: AlertSource.collar,
        latitude: 8.04,
        longitude: 80.91,
        severity: AlertSeverity.high,
        createdAt: currentTime,
      );
      await localDataSource.upsertAlert(alert);

      // 1. Assign responder (newAlert -> assigned)
      currentTime = currentTime.add(const Duration(minutes: 2));
      final assignment = await repo.assignResponder(
        alertId: alert.id,
        responderId: responder.id,
        assignedBy: 'Officer Perera',
      );

      // 2. Responder acknowledges assignment (assigned -> acknowledged)
      currentTime = currentTime.add(const Duration(minutes: 3));
      await repo.acknowledgeAssignment(
        assignmentId: assignment.id,
        responderId: responder.id,
      );

      // 3. Responder starts response (acknowledged -> responseInProgress)
      currentTime = currentTime.add(const Duration(minutes: 5));
      await repo.startResponse(assignment.id);

      // Record outcome
      currentTime = currentTime.add(const Duration(minutes: 5));
      await repo.recordOutcome(
        assignmentId: assignment.id,
        outcome: 'Herd safely turned away towards park interior',
      );

      // 4. Resolve alert (responseInProgress -> resolved)
      currentTime = currentTime.add(const Duration(minutes: 10));
      await repo.resolveAlert(alert.id);

      // Verify complete status history timeline
      final history = await repo.getStatusHistory(alert.id);
      expect(history.length, greaterThanOrEqualTo(4));

      final transitions = history.map((h) => h.toStatus).toList();
      expect(transitions, containsAll([
        AlertStatus.assigned,
        AlertStatus.acknowledged,
        AlertStatus.responseInProgress,
        AlertStatus.resolved,
      ]));
    });

    test('automatic overdue escalation when configurable threshold exceeded', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      var clockTime = DateTime.utc(2026, 9, 25, 10, 0, 0);
      const responder = AppUser(
        id: 'U002',
        name: 'Ranger Silva',
        email: 'silva@park.lk',
        role: UserRole.ranger,
        parkId: 'PARK-MIN',
      );

      final localDataSource = ConflictLocalDataSource(db);
      final repo = DriftConflictRepository(
        localDataSource: localDataSource,
        notificationService: SimulatedNotificationService(),
        responders: [responder],
        now: () => clockTime,
      );

      final alert = WildlifeRiskAlert.create(
        parkId: 'PARK-MIN',
        source: AlertSource.collar,
        latitude: 8.04,
        longitude: 80.91,
        severity: AlertSeverity.high,
        createdAt: clockTime,
      );
      await localDataSource.upsertAlert(alert);

      // Assign at 10:00 (alert status becomes assigned)
      await repo.assignResponder(
        alertId: alert.id,
        responderId: responder.id,
        assignedBy: 'Officer Perera',
      );

      // Check within threshold: 2 minutes later with 5-minute threshold -> not overdue
      clockTime = clockTime.add(const Duration(minutes: 2));
      final initialCheck = await repo.checkAndEscalateOverdueAlerts(
        parkId: 'PARK-MIN',
        config: const ConflictConfig(acknowledgementTimeout: Duration(minutes: 5)),
      );
      expect(initialCheck, isEmpty);

      // Move clock forward by 8 more minutes (10 minutes elapsed > 5 min threshold)
      clockTime = clockTime.add(const Duration(minutes: 8));

      // Run overdue check with 5-minute threshold -> overdue!
      final escalatedAlerts = await repo.checkAndEscalateOverdueAlerts(
        parkId: 'PARK-MIN',
        config: const ConflictConfig(acknowledgementTimeout: Duration(minutes: 5)),
      );

      expect(escalatedAlerts.any((a) => a.id == alert.id), isTrue);

      // Verify status change record for escalation was generated
      final history = await repo.getStatusHistory(alert.id);
      expect(
        history.any((h) => h.reason?.contains('Automatic overdue escalation') ?? false),
        isTrue,
      );
    });

    test('records DeliveryState and allows retry on response assignment', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const responder = AppUser(
        id: 'U002',
        name: 'Ranger Silva',
        email: 'silva@park.lk',
        role: UserRole.ranger,
        parkId: 'PARK-MIN',
      );

      final localDataSource = ConflictLocalDataSource(db);
      final repo = DriftConflictRepository(
        localDataSource: localDataSource,
        notificationService: SimulatedNotificationService(),
        responders: [responder],
      );

      final alert = WildlifeRiskAlert.create(
        parkId: 'PARK-MIN',
        source: AlertSource.collar,
        latitude: 8.04,
        longitude: 80.91,
        severity: AlertSeverity.high,
        createdAt: DateTime.utc(2026, 9, 25, 10, 0, 0),
      );
      await localDataSource.upsertAlert(alert);

      final assignment = await repo.assignResponder(
        alertId: alert.id,
        responderId: responder.id,
        assignedBy: 'Manager',
      );

      expect(assignment.deliveryState, DeliveryState.delivered);

      // Simulate delivery retry
      final retriedAssignment = await repo.retryNotificationDelivery(assignment.id);
      expect(retriedAssignment.deliveryState, DeliveryState.delivered);

      final reloaded = await repo.getAssignment(assignment.id);
      expect(reloaded?.deliveryState, DeliveryState.delivered);
    });
  });
}

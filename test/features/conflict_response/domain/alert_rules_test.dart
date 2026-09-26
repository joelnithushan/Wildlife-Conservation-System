import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/acknowledgement_monitor.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/alert_rules.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/conflict_config.dart';
import 'package:wildlife_conservation_system/shared/models/response_assignment.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';

void main() {
  final now = DateTime.utc(2026, 9, 26, 10, 0, 0);

  WildlifeRiskAlert alert(AlertStatus status) => WildlifeRiskAlert(
        id: 'A1',
        parkId: 'PARK-MIN',
        source: AlertSource.collar,
        latitude: 8.03,
        longitude: 80.90,
        severity: AlertSeverity.high,
        createdAt: now,
        status: status,
        riskZoneId: 'RZ-01',
      );

  ResponseAssignment assignment({String? outcome}) => ResponseAssignment(
        id: 'AS1',
        alertId: 'A1',
        responderId: 'R001',
        responderRole: ResponderRole.ranger,
        assignedBy: 'PM001',
        assignedAt: now,
        outcome: outcome,
      );

  group('status transitions', () {
    test('legal transition passes', () {
      expect(
        () => AlertRules.assertTransition(
            AlertStatus.newAlert, AlertStatus.assigned),
        returnsNormally,
      );
    });

    test('illegal transition throws (resolved <- new)', () {
      expect(
        () => AlertRules.assertTransition(
            AlertStatus.newAlert, AlertStatus.resolved),
        throwsA(isA<ConflictException>()),
      );
    });

    test('cannot revert resolved -> assigned', () {
      expect(
        () => AlertRules.assertTransition(
            AlertStatus.resolved, AlertStatus.assigned),
        throwsA(isA<ConflictException>()),
      );
    });
  });

  group('resolvability', () {
    test('resolvable only when in progress with an outcome', () {
      expect(
        () => AlertRules.assertResolvable(
          alert(AlertStatus.responseInProgress),
          [assignment(outcome: 'Done')],
        ),
        returnsNormally,
      );
    });

    test('not resolvable without an outcome', () {
      expect(
        () => AlertRules.assertResolvable(
          alert(AlertStatus.responseInProgress),
          [assignment()],
        ),
        throwsA(isA<ConflictException>()),
      );
    });

    test('not resolvable directly from new', () {
      expect(
        () => AlertRules.assertResolvable(alert(AlertStatus.newAlert), const []),
        throwsA(isA<ConflictException>()),
      );
    });
  });

  group('acknowledgement monitor', () {
    test('not overdue before timeout', () {
      expect(
        AcknowledgementMonitor.isOverdue(assignment(),
            now: now.add(const Duration(minutes: 5))),
        isFalse,
      );
    });

    test('overdue after timeout', () {
      expect(
        AcknowledgementMonitor.isOverdue(assignment(),
            now: now.add(const Duration(minutes: 20))),
        isTrue,
      );
    });

    test('acknowledged assignment is never overdue', () {
      final acked = assignment().copyWith(acknowledgedAt: now);
      expect(
        AcknowledgementMonitor.isOverdue(acked,
            now: now.add(const Duration(hours: 5)),
            config: ConflictConfig.defaults),
        isFalse,
      );
    });
  });
}

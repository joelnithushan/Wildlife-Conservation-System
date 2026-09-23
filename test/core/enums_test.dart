import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';

void main() {
  group('Enum values match frozen design', () {
    test('PatrolStatus', () {
      expect(PatrolStatus.values,
          [PatrolStatus.assigned, PatrolStatus.inProgress, PatrolStatus.completed]);
    });

    test('SyncState', () {
      expect(SyncState.values,
          [SyncState.pending, SyncState.synchronized, SyncState.failed]);
    });

    test('AlertStatus includes assigned', () {
      expect(AlertStatus.values, containsAll([
        AlertStatus.newAlert,
        AlertStatus.assigned,
        AlertStatus.acknowledged,
        AlertStatus.responseInProgress,
        AlertStatus.resolved,
      ]));
    });

    test('UserRole', () {
      expect(UserRole.values, containsAll([
        UserRole.ranger,
        UserRole.parkManager,
        UserRole.communityLiaisonOfficer,
        UserRole.conservationResearcher,
      ]));
    });

    test('DeliveryState / ResponderRole / AlertSource', () {
      expect(DeliveryState.values,
          [DeliveryState.pending, DeliveryState.delivered, DeliveryState.failed]);
      expect(ResponderRole.values,
          [ResponderRole.ranger, ResponderRole.communityLiaisonOfficer]);
      expect(AlertSource.values, [AlertSource.collar, AlertSource.communityReport]);
    });
  });

  group('Enum serialization round trip', () {
    test('wire name is stable and parses back', () {
      for (final value in ReviewStatus.values) {
        expect(
            parseEnum(ReviewStatus.values, value.wire,
                fallback: ReviewStatus.rejected),
            value);
      }
    });

    test('parseEnum falls back on unknown/null', () {
      expect(parseEnum(SyncState.values, 'nope', fallback: SyncState.failed),
          SyncState.failed);
      expect(parseEnum(SyncState.values, null, fallback: SyncState.pending),
          SyncState.pending);
    });

    test('parseEnumOrNull returns null on unknown', () {
      expect(parseEnumOrNull(AlertStatus.values, 'ghost'), isNull);
      expect(parseEnumOrNull(AlertStatus.values, 'assigned'), AlertStatus.assigned);
    });
  });

  group('PatrolStatus transitions', () {
    test('valid forward transitions', () {
      expect(PatrolStatus.assigned.canTransitionTo(PatrolStatus.inProgress), isTrue);
      expect(PatrolStatus.inProgress.canTransitionTo(PatrolStatus.completed), isTrue);
    });

    test('invalid transitions are rejected', () {
      expect(PatrolStatus.assigned.canTransitionTo(PatrolStatus.completed), isFalse);
      expect(PatrolStatus.completed.canTransitionTo(PatrolStatus.inProgress), isFalse);
      expect(PatrolStatus.inProgress.canTransitionTo(PatrolStatus.assigned), isFalse);
    });
  });

  group('AlertStatus transitions', () {
    test('full lifecycle is valid step by step', () {
      expect(AlertStatus.newAlert.canTransitionTo(AlertStatus.assigned), isTrue);
      expect(AlertStatus.assigned.canTransitionTo(AlertStatus.acknowledged), isTrue);
      expect(
          AlertStatus.acknowledged.canTransitionTo(AlertStatus.responseInProgress),
          isTrue);
      expect(AlertStatus.responseInProgress.canTransitionTo(AlertStatus.resolved),
          isTrue);
    });

    test('skips are rejected', () {
      expect(AlertStatus.newAlert.canTransitionTo(AlertStatus.resolved), isFalse);
      expect(AlertStatus.resolved.canTransitionTo(AlertStatus.newAlert), isFalse);
    });
  });
}

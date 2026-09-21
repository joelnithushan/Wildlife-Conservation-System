import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/shared/models/enums.dart';

void main() {
  group('SyncStatus', () {
    test('contains all required values', () {
      expect(SyncStatus.values, containsAll([
        SyncStatus.pending,
        SyncStatus.syncing,
        SyncStatus.synchronized,
        SyncStatus.failed,
      ]));
    });
  });

  group('PatrolStatus', () {
    test('contains all required values', () {
      expect(PatrolStatus.values, containsAll([
        PatrolStatus.assigned,
        PatrolStatus.inProgress,
        PatrolStatus.completed,
      ]));
    });
  });

  group('AlertStatus', () {
    test('contains all required values', () {
      expect(AlertStatus.values, containsAll([
        AlertStatus.newAlert,
        AlertStatus.acknowledged,
        AlertStatus.responseInProgress,
        AlertStatus.resolved,
      ]));
    });
  });
}

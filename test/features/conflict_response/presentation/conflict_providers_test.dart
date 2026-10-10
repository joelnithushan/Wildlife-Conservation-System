import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/datasources/conflict_local_data_source.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/alert_rules.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/providers/conflict_providers.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';
import 'package:wildlife_conservation_system/shared/providers/providers.dart';
import 'package:wildlife_conservation_system/shared/session/current_user.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';

import '../../../patrol/helpers.dart';

/// Current user = ranger R001, so the controller (which uses the current user's
/// id as the acting responder) can acknowledge its own assignment.
class _ResponderUser extends CurrentUserNotifier {
  @override
  AppUser build() => DemoData.rangerPerera;
}

void main() {
  final fixedNow = DateTime.utc(2026, 9, 26, 10, 0, 0);
  const park = 'PARK-MIN';

  late AppDatabase db;
  late ProviderContainer container;

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        currentUserProvider.overrideWith(_ResponderUser.new),
      ]);

  WildlifeRiskAlert seededAlert({
    String id = 'A1',
    String parkId = park,
    AlertStatus status = AlertStatus.newAlert,
    double lat = 8.030,
    double lon = 80.900,
  }) =>
      WildlifeRiskAlert(
        id: id,
        parkId: parkId,
        source: AlertSource.collar,
        latitude: lat,
        longitude: lon,
        severity: AlertSeverity.high,
        createdAt: fixedNow,
        animalId: 'EL-07',
        riskZoneId: 'RZ-01',
        status: status,
      );

  // Keep the repository's demo auto-seed from firing, then seed a known alert.
  Future<void> seed(ConflictLocalDataSource local) async {
    await local.upsertAlert(WildlifeRiskAlert(
      id: 'SENTINEL',
      parkId: 'ZZZ',
      source: AlertSource.collar,
      latitude: 1,
      longitude: 1,
      severity: AlertSeverity.low,
      createdAt: fixedNow,
      animalId: 'ZZZ',
      riskZoneId: 'ZZZ',
      status: AlertStatus.resolved,
    ));
    await local.upsertAlert(seededAlert());
  }

  setUp(() {
    db = createTestDatabase();
    container = makeContainer();
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  test('config provider derives the acknowledgement timeout from the threshold',
      () {
    container
        .read(acknowledgementThresholdMinutesProvider.notifier)
        .setThreshold(5);
    expect(container.read(conflictConfigProvider).acknowledgementTimeout,
        const Duration(minutes: 5));
  });

  test('read providers expose reference data', () async {
    expect(await container.read(riskZonesProvider(park).future), isNotEmpty);
    expect(await container.read(trackedAnimalsProvider.future), isNotEmpty);
    expect(await container.read(availableRespondersProvider(park).future),
        isNotEmpty);
  });

  test('simulateCollarReading creates an alert surfaced by riskAlertsProvider',
      () async {
    final local = container.read(conflictLocalDataSourceProvider);
    // Suppress demo seeding without a competing open alert in the zone.
    await local.upsertAlert(WildlifeRiskAlert(
      id: 'SENTINEL',
      parkId: 'ZZZ',
      source: AlertSource.collar,
      latitude: 1,
      longitude: 1,
      severity: AlertSeverity.low,
      createdAt: fixedNow,
      animalId: 'ZZZ',
      riskZoneId: 'ZZZ',
      status: AlertStatus.resolved,
    ));

    final alert = await container
        .read(conflictControllerProvider.notifier)
        .simulateCollarReading(
            animalId: 'EL-07', latitude: 8.030, longitude: 80.900);

    expect(alert, isNotNull);
    final alerts = await container.read(riskAlertsProvider(park).future);
    expect(alerts.any((a) => a.id == alert!.id), isTrue);
  });

  test('submit + verify community report runs the pipeline', () async {
    final local = container.read(conflictLocalDataSourceProvider);
    await local.upsertAlert(WildlifeRiskAlert(
      id: 'SENTINEL',
      parkId: 'ZZZ',
      source: AlertSource.collar,
      latitude: 1,
      longitude: 1,
      severity: AlertSeverity.low,
      createdAt: fixedNow,
      animalId: 'ZZZ',
      riskZoneId: 'ZZZ',
      status: AlertStatus.resolved,
    ));
    final controller = container.read(conflictControllerProvider.notifier);

    final report = await controller.submitCommunityReport(
      parkId: park,
      description: 'Elephant at fence',
      latitude: 8.030,
      longitude: 80.900,
    );
    final reports = await container.read(communityReportsProvider(park).future);
    expect(reports.any((r) => r.id == report.id), isTrue);

    final alert = await controller.verifyAndProcessCommunityReport(report.id);
    expect(alert, isNotNull);
    expect(alert!.source, AlertSource.communityReport);
  });

  test('full assignment lifecycle flows through the controller + read providers',
      () async {
    final local = container.read(conflictLocalDataSourceProvider);
    await seed(local);
    final controller = container.read(conflictControllerProvider.notifier);

    final assignment =
        await controller.assignResponder(alertId: 'A1', responderId: 'R001');
    expect((await container.read(alertProvider('A1').future))!.status,
        AlertStatus.assigned);
    expect(await container.read(activeAssignmentProvider('A1').future),
        isNotNull);

    await controller.acknowledge(assignment.id);
    expect((await container.read(alertProvider('A1').future))!.status,
        AlertStatus.acknowledged);

    await controller.startResponse(assignment.id);
    await controller.updateStatus(
        assignmentId: assignment.id, note: 'On scene');
    await controller.recordOutcome(
        assignmentId: assignment.id, outcome: 'Animal herded');
    final resolved = await controller.resolveAlert('A1');
    expect(resolved.status, AlertStatus.resolved);

    // History provider reflects the lifecycle transitions.
    expect(await container.read(alertStatusHistoryProvider('A1').future),
        isNotEmpty);
    expect(await container.read(assignmentsForAlertProvider('A1').future),
        isNotEmpty);
  });

  test('retryNotificationDelivery returns an updated assignment', () async {
    final local = container.read(conflictLocalDataSourceProvider);
    await seed(local);
    final controller = container.read(conflictControllerProvider.notifier);
    final a = await controller.assignResponder(alertId: 'A1', responderId: 'R001');
    final retried = await controller.retryNotificationDelivery(a.id);
    expect(retried.id, a.id);
  });

  test('checkAndEscalateOverdue flags an unacknowledged assignment', () async {
    final local = container.read(conflictLocalDataSourceProvider);
    await seed(local);
    container
        .read(acknowledgementThresholdMinutesProvider.notifier)
        .setThreshold(0); // any assigned alert is immediately overdue
    final controller = container.read(conflictControllerProvider.notifier);
    await controller.assignResponder(alertId: 'A1', responderId: 'R001');

    final overdue = await controller.checkAndEscalateOverdue(park);
    expect(overdue.map((a) => a.id), contains('A1'));
  });

  test('a failed mutation surfaces as AsyncError and rethrows', () async {
    final local = container.read(conflictLocalDataSourceProvider);
    await seed(local);
    final controller = container.read(conflictControllerProvider.notifier);

    await expectLater(
      controller.assignResponder(alertId: 'ghost', responderId: 'R001'),
      throwsA(isA<ConflictException>()),
    );
    expect(container.read(conflictControllerProvider).hasError, isTrue);
  });
}

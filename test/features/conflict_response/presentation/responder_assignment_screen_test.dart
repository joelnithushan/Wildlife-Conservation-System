import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/datasources/conflict_local_data_source.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/notification/simulated_notification_service.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/drift_conflict_repository.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/screens/responder_assignment_screen.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';
import 'package:wildlife_conservation_system/shared/providers/providers.dart';
import 'package:wildlife_conservation_system/shared/session/current_user.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';

import '../../../patrol/helpers.dart';

class _ResponderUser extends CurrentUserNotifier {
  @override
  AppUser build() => DemoData.rangerPerera; // R001
}

class _ManagerUser extends CurrentUserNotifier {
  @override
  AppUser build() => DemoData.parkManager; // PM001 (not the responder)
}

void main() {
  final fixedNow = DateTime.utc(2026, 9, 26, 10, 0, 0);
  const park = 'PARK-MIN';

  late AppDatabase db;

  WildlifeRiskAlert alertA1() => WildlifeRiskAlert(
        id: 'A1',
        parkId: park,
        source: AlertSource.collar,
        latitude: 8.030,
        longitude: 80.900,
        severity: AlertSeverity.high,
        createdAt: fixedNow,
        animalId: 'EL-07',
        riskZoneId: 'RZ-01',
      );

  // Seed an alert + an active assignment to R001 directly in the shared db.
  Future<void> seedAssignedToR001() async {
    final local = ConflictLocalDataSource(db);
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
    await local.upsertAlert(alertA1());
    final repo = DriftConflictRepository(
      localDataSource: local,
      notificationService: SimulatedNotificationService(),
      now: () => fixedNow,
    );
    await repo.assignResponder(
        alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
  }

  Widget wrap(Widget child, {bool asResponder = true}) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          currentUserProvider.overrideWith(
              asResponder ? _ResponderUser.new : _ManagerUser.new),
        ],
        child: MaterialApp(home: child),
      );

  Future<void> pump(WidgetTester tester, Widget child,
      {bool asResponder = true}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(child, asResponder: asResponder));
    await tester.pumpAndSettle();
  }

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('shows a not-found message for an unknown alert', (tester) async {
    await seedAssignedToR001();
    await pump(tester, const ResponderAssignmentScreen(alertId: 'ghost'));
    expect(find.text('Alert not found.'), findsOneWidget);
  });

  testWidgets('shows an empty state when the alert has no assignment',
      (tester) async {
    final local = ConflictLocalDataSource(db);
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
    await local.upsertAlert(alertA1());
    await pump(tester, const ResponderAssignmentScreen(alertId: 'A1'));
    expect(find.text('No assignment for this alert yet.'), findsOneWidget);
  });

  testWidgets('walks the full lifecycle: acknowledge → start → submit outcome',
      (tester) async {
    await seedAssignedToR001();
    await pump(tester, const ResponderAssignmentScreen(alertId: 'A1'));

    // Screen 4 — Assigned: alert summary + Acknowledge button.
    expect(find.text('Acknowledge'), findsOneWidget);
    expect(find.textContaining('Collar'), findsWidgets); // alert summary source
    await tester.tap(find.widgetWithText(ElevatedButton, 'Acknowledge'));
    await tester.pumpAndSettle();

    // Screen 5 — Acknowledged: Start Response.
    expect(find.widgetWithText(ElevatedButton, 'Start Response'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Start Response'));
    await tester.pumpAndSettle();

    // Screen 6 — In Progress: note + outcome chips + Submit.
    expect(find.text('Submit Outcome'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Interim status note (optional)'),
        'Arrived on scene');
    await tester.tap(find.text('Residents warned')); // select an outcome chip
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Outcome'));
    await tester.pumpAndSettle();

    // Outcome submitted view.
    expect(find.text('Outcome submitted'), findsOneWidget);
    expect(find.textContaining('Residents warned'), findsWidgets);
  });

  testWidgets('submitting the "Other" outcome with no text is blocked',
      (tester) async {
    await seedAssignedToR001();
    // Fast-forward to in-progress by acknowledging + starting first.
    final repo = DriftConflictRepository(
      localDataSource: ConflictLocalDataSource(db),
      notificationService: SimulatedNotificationService(),
      now: () => fixedNow,
    );
    final active = await repo.getActiveAssignment('A1');
    await repo.acknowledgeAssignment(
        assignmentId: active!.id, responderId: 'R001');
    await repo.startResponse(active.id);

    await pump(tester, const ResponderAssignmentScreen(alertId: 'A1'));
    expect(find.text('Submit Outcome'), findsOneWidget);

    await tester.tap(find.text('Other')); // needs free-text, left empty
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Outcome'));
    await tester.pumpAndSettle();

    expect(find.text('Please describe the outcome.'), findsOneWidget);
  });

  testWidgets('a non-responder sees the "Act as" affordance and can take over',
      (tester) async {
    await seedAssignedToR001();
    // Current user is the manager (not R001) → acknowledge is disabled.
    await pump(tester, const ResponderAssignmentScreen(alertId: 'A1'),
        asResponder: false);

    final ackButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Acknowledge'));
    expect(ackButton.onPressed, isNull); // disabled for a non-assignee
    expect(find.textContaining('Act as'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Act as K. Perera'));
    await tester.pumpAndSettle();

    // After taking over, Acknowledge is enabled.
    final ackAfter = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Acknowledge'));
    expect(ackAfter.onPressed, isNotNull);
  });
}

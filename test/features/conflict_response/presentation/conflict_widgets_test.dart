import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/notification/simulated_notification_service.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/in_memory_conflict_repository.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/providers/conflict_providers.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/screens/alert_details_screen.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/screens/assign_responder_screen.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/screens/conflict_response_screen.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/screens/responder_assignment_screen.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/screens/response_tracking_screen.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/widgets/status_chip.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';
import 'package:wildlife_conservation_system/shared/repositories/conflict_repository.dart';
import 'package:wildlife_conservation_system/shared/models/wildlife_risk_alert.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 9, 26, 10, 0, 0);

  WildlifeRiskAlert newAlert() => WildlifeRiskAlert(
        id: 'A1',
        parkId: 'PARK-MIN',
        source: AlertSource.collar,
        latitude: 8.030,
        longitude: 80.900,
        severity: AlertSeverity.high,
        createdAt: fixedNow,
        animalId: 'EL-07',
        riskZoneId: 'RZ-01',
      );

  InMemoryConflictRepository repo({
    List<WildlifeRiskAlert>? alerts,
    List<AppUser>? responders,
  }) =>
      InMemoryConflictRepository(
        seedAlerts: alerts ?? [newAlert()],
        communityReports: const [],
        responders: responders,
        notificationService: SimulatedNotificationService(),
        now: () => fixedNow,
      );

  Widget wrap(Widget child, ConflictRepository repository) => ProviderScope(
        overrides: [conflictRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: child),
      );

  testWidgets('StatusChip renders its label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StatusChip(label: 'Delivered', color: Colors.green),
      ),
    ));
    expect(find.text('Delivered'), findsOneWidget);
  });

  testWidgets('Risk Alerts screen shows alerts and filters', (tester) async {
    await tester.pumpWidget(wrap(const ConflictResponseScreen(), repo()));
    await tester.pumpAndSettle();
    expect(find.text('Risk Alerts'), findsOneWidget);
    expect(find.text('Farmland East • High risk'), findsOneWidget);
    expect(find.text('All'), findsOneWidget); // filter chip
    expect(find.text('Resolved'), findsWidgets);
  });

  testWidgets('Alert Details offers Assign Responder for a new alert',
      (tester) async {
    await tester.pumpWidget(
        wrap(const AlertDetailsScreen(alertId: 'A1'), repo()));
    await tester.pumpAndSettle();
    expect(find.text('Assign Responder'), findsOneWidget);
    expect(find.text('Alert ID'), findsOneWidget);
  });

  testWidgets('Assign Responder lists available responders', (tester) async {
    await tester.pumpWidget(
        wrap(const AssignResponderScreen(alertId: 'A1'), repo()));
    await tester.pumpAndSettle();
    expect(find.text('K. Perera'), findsOneWidget); // available ranger
    expect(find.text('Assign & Notify'), findsOneWidget);
  });

  testWidgets('Assign Responder shows no-responder state', (tester) async {
    await tester.pumpWidget(
        wrap(const AssignResponderScreen(alertId: 'A1'), repo(responders: [])));
    await tester.pumpAndSettle();
    expect(find.text('No responder available'), findsOneWidget);
  });

  testWidgets('Responder screen shows Acknowledge for an assigned alert',
      (tester) async {
    final r = repo();
    await r.assignResponder(
        alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
    await tester.pumpWidget(
        wrap(const ResponderAssignmentScreen(alertId: 'A1'), r));
    await tester.pumpAndSettle();
    expect(find.text('Acknowledge'), findsOneWidget);
  });

  testWidgets('Response Tracking hides Resolve until an outcome exists',
      (tester) async {
    final r = repo();
    final a = await r.assignResponder(
        alertId: 'A1', responderId: 'R001', assignedBy: 'PM001');
    await r.acknowledgeAssignment(assignmentId: a.id, responderId: 'R001');
    await r.startResponse(a.id);
    await tester.pumpWidget(
        wrap(const ResponseTrackingScreen(alertId: 'A1'), r));
    await tester.pumpAndSettle();
    // The button lives at the bottom of a lazy ListView; scroll it into view.
    await tester.dragUntilVisible(
      find.text('Resolve Alert'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Resolve Alert'), findsOneWidget);
    // Disabled button still renders; helper text explains why.
    expect(
      find.textContaining('once the responder records an outcome'),
      findsOneWidget,
    );
  });
}

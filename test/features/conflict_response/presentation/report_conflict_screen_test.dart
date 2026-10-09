import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/notification/simulated_notification_service.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/in_memory_conflict_repository.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/providers/conflict_providers.dart';
import 'package:wildlife_conservation_system/features/conflict_response/presentation/screens/report_conflict_screen.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 9, 26, 10, 0, 0);

  Widget createWidget({required InMemoryConflictRepository repo}) {
    return ProviderScope(
      overrides: [
        conflictRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: ReportConflictScreen(),
      ),
    );
  }

  testWidgets('ReportConflictScreen renders input fields, badges, and action buttons',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = InMemoryConflictRepository(
      notificationService: SimulatedNotificationService(),
      now: () => fixedNow,
    );

    await tester.pumpWidget(createWidget(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Report Wildlife Conflict'), findsOneWidget);
    expect(find.text('Community Conflict Reporting'), findsOneWidget);
    expect(find.text('Channel: APP'), findsOneWidget);
    expect(find.text('Submit Conflict Report (APP)'), findsOneWidget);
    expect(find.text('Simulate SMS Report (Demo)'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets('validates required description when submitting via APP',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = InMemoryConflictRepository(
      notificationService: SimulatedNotificationService(),
      now: () => fixedNow,
    );

    await tester.pumpWidget(createWidget(repo: repo));
    await tester.pumpAndSettle();

    // Tap submit APP button with empty text
    final submitAppButton = find.text('Submit Conflict Report (APP)');
    await tester.ensureVisible(submitAppButton);
    await tester.tap(submitAppButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Please provide a brief description of the conflict or sighting.'),
      findsOneWidget,
    );
  });

  testWidgets('submits report with channel APP when form is filled',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = InMemoryConflictRepository(
      notificationService: SimulatedNotificationService(),
      now: () => fixedNow,
    );

    await tester.pumpWidget(createWidget(repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField),
      'Three elephants observed near roadside fence in Minneriya',
    );
    await tester.pumpAndSettle();

    final submitAppButton = find.text('Submit Conflict Report (APP)');
    await tester.ensureVisible(submitAppButton);
    await tester.tap(submitAppButton);
    await tester.pumpAndSettle();

    final reports = await repo.getCommunityReports('PARK-MIN');
    expect(reports, isNotEmpty);
    final submitted = reports.firstWhere(
      (r) => r.description.contains('roadside fence'),
    );
    expect(submitted.channel, 'APP');
  });

  testWidgets('simulates SMS report with channel SMS', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = InMemoryConflictRepository(
      notificationService: SimulatedNotificationService(),
      now: () => fixedNow,
    );

    await tester.pumpWidget(createWidget(repo: repo));
    await tester.pumpAndSettle();

    final smsButton = find.text('Simulate SMS Report (Demo)');
    await tester.ensureVisible(smsButton);
    await tester.tap(smsButton);
    await tester.pumpAndSettle();

    final reports = await repo.getCommunityReports('PARK-MIN');
    expect(reports, isNotEmpty);
    final smsReport = reports.firstWhere((r) => r.channel == 'SMS');
    expect(smsReport.channel, 'SMS');
    expect(smsReport.description, contains('SMS'));
  });
}

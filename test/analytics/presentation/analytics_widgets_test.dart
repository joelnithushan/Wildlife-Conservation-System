import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_messages.dart';
import 'package:wildlife_conservation_system/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:wildlife_conservation_system/features/analytics/presentation/report_flow_controller.dart';
import 'package:wildlife_conservation_system/features/analytics/presentation/screens/analytics_screen.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late ScriptedReportRepository repository;
  late RecordingExportService export;

  setUp(() {
    repository = ScriptedReportRepository([
      testReport(totalPoaching: 18, excluded: 3, snapshotId: 'snap-ui'),
    ]);
    export = RecordingExportService();
    container = ProviderContainer(
      overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
        reportExportServiceProvider.overrideWithValue(export),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AnalyticsScreen()),
      ),
    );
    await tester.pump();
  }

  ReportFlowController flow() =>
      container.read(reportFlowControllerProvider.notifier);

  testWidgets(
      'report filters list the permitted park, categories, and generate',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Conservation Reports'), findsOneWidget);
    expect(find.text('Minneriya National Park'), findsOneWidget);
    expect(find.text('Poaching'), findsWidgets);
    expect(find.text('Illegal logging'), findsOneWidget);
    expect(find.text('Generate Report'), findsOneWidget);
  });

  testWidgets('validation shows an inline error and does not generate',
      (tester) async {
    await pumpScreen(tester);
    flow().setPark(null);
    await tester.pump();

    await tester.tap(find.text('Generate Report'));
    await tester.pump();

    expect(find.text(ReportMessages.missingPark), findsOneWidget);
    expect(repository.calls, 0);

    flow()
      ..setPark('PARK-MIN')
      ..setStartDate(DateTime.utc(2026, 5, 10))
      ..setEndDate(DateTime.utc(2026, 5, 1));
    await tester.pump();
    await tester.tap(find.text('Generate Report'));
    await tester.pump();

    expect(find.text(ReportMessages.invalidRange), findsOneWidget);
    expect(repository.calls, 0);
  });

  testWidgets('generating state then shows report result cards',
      (tester) async {
    repository = ScriptedReportRepository(
      [testReport(totalPoaching: 18, excluded: 3, snapshotId: 'snap-ui')],
      delay: const Duration(milliseconds: 40),
    );
    container.dispose();
    container = ProviderContainer(
      overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
        reportExportServiceProvider.overrideWithValue(export),
      ],
    );
    await pumpScreen(tester);
    flow()
      ..setStartDate(DateTime.utc(2026, 3, 1))
      ..setEndDate(DateTime.utc(2026, 3, 31));
    await tester.pump();

    await tester.tap(find.text('Generate Report'));
    await tester.pump();
    expect(find.text(ReportMessages.generating), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.text('Total incidents'), findsOneWidget);
    expect(find.text('18'), findsWidgets);
    expect(find.text('Patrol coverage'), findsOneWidget);
    expect(find.text('80.0%'), findsOneWidget);
    expect(find.text('Conflict alerts'), findsOneWidget);
    expect(find.text(ReportMessages.pendingExcluded(3)), findsOneWidget);
    expect(find.text('Change Filters'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(export.calls, 0);
  });

  testWidgets('empty report shows zeros and the no-records message',
      (tester) async {
    repository = ScriptedReportRepository([
      testReport(
        totalPoaching: 0,
        coverage: 0,
        completedPatrols: 0,
        openAlerts: 0,
        resolvedAlerts: 0,
        excluded: 0,
      ),
    ]);
    container.dispose();
    container = ProviderContainer(
      overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
        reportExportServiceProvider.overrideWithValue(export),
      ],
    );
    await pumpScreen(tester);
    flow()
      ..setStartDate(DateTime.utc(2026, 3, 1))
      ..setEndDate(DateTime.utc(2026, 3, 31));
    await tester.pump();
    await tester.tap(find.text('Generate Report'));
    await tester.pump();

    expect(find.text(ReportMessages.empty), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('N/A'), findsOneWidget);
    expect(find.text('Change Filters'), findsOneWidget);
  });

  testWidgets('service unavailable keeps filters and offers retry',
      (tester) async {
    repository = ScriptedReportRepository([dataServiceDown]);
    container.dispose();
    container = ProviderContainer(
      overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
        reportExportServiceProvider.overrideWithValue(export),
      ],
    );
    await pumpScreen(tester);
    flow()
      ..setStartDate(DateTime.utc(2026, 3, 1))
      ..setEndDate(DateTime.utc(2026, 3, 31));
    await tester.pump();
    await tester.tap(find.text('Generate Report'));
    await tester.pump();

    expect(find.text(ReportMessages.serviceUnavailable), findsOneWidget);
    expect(find.text('Total incidents'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('PARK-MIN'), findsWidgets);
    expect(find.text('Change Filters'), findsOneWidget);
  });

  testWidgets('export options use the snapshot already on screen',
      (tester) async {
    await pumpScreen(tester);
    flow()
      ..setStartDate(DateTime.utc(2026, 3, 1))
      ..setEndDate(DateTime.utc(2026, 3, 31));
    await tester.pump();
    await tester.tap(find.text('Generate Report'));
    await tester.pump();
    await tester.tap(find.text('Export'));
    await tester.pump();

    expect(find.text(ReportMessages.exportSameSnapshot), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.textContaining('snap-ui'), findsOneWidget);

    await tester.tap(find.text('PDF'));
    await tester.pump();
    expect(export.calls, 1);
    expect(export.pdfReport?.snapshotId, 'snap-ui');
  });
}

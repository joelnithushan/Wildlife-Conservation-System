import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_messages.dart';
import 'package:wildlife_conservation_system/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:wildlife_conservation_system/features/analytics/presentation/screens/analytics_screen.dart';

import '../helpers.dart';

void main() {
  testWidgets('a ranger cannot generate a report from the reports screen',
      (tester) async {
    final repository = ScriptedReportRepository([testReport()]);
    final container = ProviderContainer(
      overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
        reportExportServiceProvider.overrideWithValue(RecordingExportService()),
      ],
    );
    addTearDown(container.dispose);

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

    await tester.tap(find.byTooltip('Switch demo role'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranger').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text(ReportMessages.accessDenied), findsOneWidget);
    expect(find.text('Generate Report'), findsNothing);
    expect(repository.calls, 0);
  });
}

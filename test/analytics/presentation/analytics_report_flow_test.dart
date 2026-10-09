import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_messages.dart';

import '../../../integration_test/support/report_flow_harness.dart';

/// Same UC04 path as [integration_test/analytics_report_flow_test.dart], run by
/// `flutter test` when no device target is attached.
void main() {
  testWidgets('invalid filters do not read report data', (tester) async {
    final harness = await ReportFlowHarness.pump(tester);

    await tester.tap(find.text('Conservation Reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate Report'));
    await tester.pumpAndSettle();

    expect(find.text(ReportMessages.missingStart), findsOneWidget);
    expect(find.text('Total incidents'), findsNothing);
    expect(harness.store.loads, 0);
  });

  testWidgets('researcher generates one snapshot and exports that same report',
      (tester) async {
    final harness = await ReportFlowHarness.pump(tester, researcher: true);

    expect(find.text('Conservation Researcher'), findsWidgets);
    await tester.tap(find.text('Conservation Reports'));
    await tester.pumpAndSettle();

    expect(find.text('Minneriya National Park'), findsWidgets);
    await confirmDatePicker(tester);
    await confirmDatePicker(tester);

    await tester.tap(find.text('Generate Report'));
    await tester.pumpAndSettle();

    expect(find.text(ReportMessages.generating), findsNothing);
    expect(find.text('Total incidents'), findsOneWidget);
    expect(find.text('Poaching: 1'), findsOneWidget);
    expect(find.text('80.0%'), findsOneWidget);
    expect(find.text('Conflict alerts'), findsOneWidget);
    expect(find.text(ReportMessages.pendingExcluded(1)), findsOneWidget);
    expect(harness.store.loads, 1);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.text(ReportMessages.exportSameSnapshot), findsOneWidget);
    final snapshotId = tester
        .widget<Text>(find.textContaining('Snapshot '))
        .data!
        .replaceFirst('Snapshot ', '');

    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();

    expect(harness.store.loads, 1, reason: 'export must not re-query');
    expect(find.textContaining(snapshotId), findsWidgets);
    final csvName = 'conservation-$snapshotId.csv';
    final pdfName = 'conservation-$snapshotId.pdf';
    expect(utf8.decode(harness.saved[csvName]!), contains(snapshotId));
    expect(utf8.decode(harness.saved[csvName]!), contains('incidents,total,1'));
    expect(
      utf8.decode(harness.saved[csvName]!),
      contains('metadata,excludedPendingCount,1'),
    );
    expect(harness.saved[pdfName], isNotEmpty);

    await tester.tap(find.text('Back to report'));
    await tester.pumpAndSettle();
    expect(find.text('Total incidents'), findsOneWidget);
    expect(find.text(ReportMessages.pendingExcluded(1)), findsOneWidget);
  });
}

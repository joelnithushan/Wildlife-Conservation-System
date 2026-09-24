import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_messages.dart';
import 'package:wildlife_conservation_system/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:wildlife_conservation_system/features/analytics/presentation/report_flow_controller.dart';

import '../helpers.dart';

void main() {
  late ScriptedReportRepository repository;
  late RecordingExportService export;
  late ProviderContainer container;

  setUp(() {
    repository = ScriptedReportRepository([
      testReport(snapshotId: 'snap-a', totalPoaching: 5),
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

  ReportFlowController flow() =>
      container.read(reportFlowControllerProvider.notifier);

  ReportFlowState current() => container.read(reportFlowControllerProvider);

  void selectMarch() {
    flow()
      ..setStartDate(DateTime.utc(2026, 3, 1))
      ..setEndDate(DateTime.utc(2026, 3, 31));
  }

  test('invalid filters do not query, including a reversed date range',
      () async {
    flow().setPark(null);
    await flow().generate();
    expect(current().validationError, ReportMessages.missingPark);
    expect(repository.calls, 0);

    flow().setPark('PARK-OTHER');
    await flow().generate();
    expect(current().validationError, ReportMessages.unauthorizedPark);
    expect(repository.calls, 0);

    flow()
      ..setPark('PARK-MIN')
      ..setStartDate(DateTime.utc(2026, 4, 2))
      ..setEndDate(DateTime.utc(2026, 4, 1));
    await flow().generate();
    expect(current().validationError, ReportMessages.invalidRange);
    expect(repository.calls, 0);
  });

  test('19. export is optional after a report is generated', () async {
    selectMarch();
    await flow().generate();
    expect(current().step, ReportStep.results);
    expect(current().report, isNotNull);
    expect(export.calls, 0);
  });

  test(
      '20-22. export uses the shown snapshot and a new report leaves the old one unchanged',
      () async {
    selectMarch();
    await flow().generate();
    final shown = current().report!;

    flow().openExport();
    await flow().exportPdf();
    await flow().exportCsv();
    expect(identical(export.pdfReport, shown), isTrue);
    expect(identical(export.csvReport, shown), isTrue);

    repository.results.add(testReport(snapshotId: 'snap-b', totalPoaching: 9));
    flow()
      ..changeFilters()
      ..setEndDate(DateTime.utc(2026, 3, 20));
    await flow().generate();

    expect(shown.totalIncidents, 5);
    expect(shown.snapshotId, 'snap-a');
    expect(current().report!.snapshotId, 'snap-b');
    expect(repository.calls, 2);
  });

  test('23. export failure keeps the existing report', () async {
    selectMarch();
    await flow().generate();
    final shown = current().report!;
    export.failure = Exception('disk full');
    flow().openExport();
    await flow().exportPdf();

    expect(identical(current().report, shown), isTrue);
    expect(current().exportError, ReportMessages.pdfFailed);
    expect(current().step, ReportStep.export);
    expect(repository.calls, 1);
  });

  test('24. export without a generated report is rejected', () async {
    await flow().exportCsv();
    expect(export.calls, 0);
    expect(current().exportError, ReportMessages.exportBeforeReport);
    expect(current().report, isNull);
  });

  test('a data-service failure keeps the selected filters and drops any report',
      () async {
    selectMarch();
    repository.results
      ..clear()
      ..add(dataServiceDown);
    await flow().generate();

    expect(current().step, ReportStep.unavailable);
    expect(current().serviceError, ReportMessages.serviceUnavailable);
    expect(current().report, isNull);
    expect(current().parkId, 'PARK-MIN');
    expect(current().startDate, DateTime.utc(2026, 3, 1));
  });
}

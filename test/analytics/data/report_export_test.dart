import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/analytics/data/report_document_builder.dart';
import 'package:wildlife_conservation_system/features/analytics/data/report_export_service_impl.dart';
import 'package:wildlife_conservation_system/shared/models/conservation_report.dart';

import '../helpers.dart';

void main() {
  test('19. viewing a report does not require export', () {
    final report = testReport();
    expect(report.totalIncidents, 4);
    expect(report.snapshotId, isNotEmpty);
  });

  test('20-21. PDF and CSV are built from the same generated report', () async {
    final report =
        testReport(snapshotId: 'snap-export', totalPoaching: 18, excluded: 3);
    final other =
        testReport(snapshotId: 'snap-other', totalPoaching: 1, excluded: 0);

    final lines = describeReport(report);
    final text = lines.join('\n');
    expect(text, contains('snap-export'));
    expect(text, contains('Total incidents: 18'));
    expect(text, contains('Snare: 18'));
    expect(text, contains('Excluded pending field records: 3'));
    expect(text, contains(report.dataCutoff.toUtc().toIso8601String()));
    expect(text, contains('Minneriya National Park'));
    expect(text, isNot(contains('snap-other')));

    final csv = buildReportCsv(report);
    expect(csv, contains('snap-export'));
    expect(csv, contains('incidents,total,18'));
    expect(csv, contains('incidents,snare,18'));
    expect(csv, contains('metadata,excludedPendingCount,3'));
    expect(
        csv,
        contains(
            'metadata,dataCutoff,${report.dataCutoff.toUtc().toIso8601String()}'));
    expect(csv, isNot(contains('snap-other')));

    final saved = <String, List<int>>{};
    final service = ReportExportServiceImpl(
      save: (name, bytes) async {
        saved[name] = bytes;
        return name;
      },
    );
    final pdfPath = await service.exportPdf(report);
    final csvPath = await service.exportCsv(report);

    expect(pdfPath, contains('snap-export'));
    expect(csvPath, contains('snap-export'));
    expect(utf8.decode(saved[csvPath]!), buildReportCsv(report));
    expect(saved[pdfPath], isNotEmpty);
    expect(await buildReportPdfBytes(report),
        isNot(await buildReportPdfBytes(other)));
  });

  test('23. an export failure does not change the report', () async {
    final report = testReport();
    final before = report.toMap();
    final service = ReportExportServiceImpl(
      save: (name, bytes) async => throw Exception('disk full'),
    );

    await expectLater(service.exportPdf(report), throwsException);
    await expectLater(service.exportCsv(report), throwsException);
    expect(report.toMap(), before);
  });

  test('a report without snapshot criteria cannot be exported', () {
    final report = ConservationReport(
      incidentCounts: const {},
      patrolCoverage: 0,
      conflictTrends: const [],
      dataCutoff: DateTime.utc(2026, 4, 1),
      excludedPendingCount: 0,
      generatedAt: DateTime.utc(2026, 4, 1),
    );
    expect(() => buildReportCsv(report), throwsFormatException);
    expect(() => describeReport(report), throwsFormatException);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/analytics/data/memory_report_read_store.dart';
import 'package:wildlife_conservation_system/features/analytics/data/report_export_service_impl.dart';
import 'package:wildlife_conservation_system/features/analytics/data/report_repository_impl.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_source_data.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';

import '../helpers.dart';

void main() {
  test('PDF and CSV export do not load source records again', () async {
    final store = MemoryReportReadStore(
      ReportSourceData(
        incidents: [
          testIncident(id: 'synced'),
          testIncident(id: 'pending', syncState: SyncState.pending),
        ],
        patrols: [testPatrol(id: 'done', coveragePercent: 80)],
      ),
    );
    final report = await ReportRepositoryImpl(
      store: store,
      currentUser: () => DemoData.researcher,
      now: () => DateTime.utc(2026, 4, 1),
      newSnapshotId: () => 'snap-export-once',
    ).generateReport(testCriteria());
    expect(store.loads, 1);
    final before = report.toMap();

    final saved = <String, List<int>>{};
    final export = ReportExportServiceImpl(
      save: (name, bytes) async {
        saved[name] = bytes;
        return name;
      },
    );

    final pdfPath = await export.exportPdf(report);
    final csvPath = await export.exportCsv(report);

    expect(store.loads, 1, reason: 'export must not re-query the read store');
    expect(report.toMap(), before);
    expect(pdfPath, 'conservation-snap-export-once.pdf');
    expect(csvPath, 'conservation-snap-export-once.csv');
    final csv = utf8.decode(saved[csvPath]!);
    expect(csv, contains('snap-export-once'));
    expect(csv, contains('incidents,total,1'));
    expect(csv, contains('metadata,excludedPendingCount,1'));
    expect(saved[pdfPath], isNotEmpty);
  });
}

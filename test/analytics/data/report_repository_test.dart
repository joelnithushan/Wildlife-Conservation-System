import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/errors/exceptions.dart';
import 'package:wildlife_conservation_system/features/analytics/data/memory_report_read_store.dart';
import 'package:wildlife_conservation_system/features/analytics/data/report_repository_impl.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_messages.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_source_data.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';

import '../helpers.dart';

void main() {
  test('repository reads once and records the cutoff', () async {
    final store = MemoryReportReadStore(
      ReportSourceData(incidents: [testIncident(id: 'a')]),
    );
    final now = DateTime.utc(2026, 4, 1, 10);
    final repo = ReportRepositoryImpl(
      store: store,
      currentUser: () => DemoData.parkManager,
      now: () => now,
      newSnapshotId: () => 'snap-fixed',
    );

    final report = await repo.generateReport(testCriteria());

    expect(store.loads, 1);
    expect(report.snapshotId, 'snap-fixed');
    expect(report.dataCutoff, now);
    expect(report.totalIncidents, 1);
    expect(report.parkName, 'Minneriya National Park');
  });

  test('13. an unauthorized park is rejected before any read', () async {
    final store = MemoryReportReadStore(const ReportSourceData());
    final repo = ReportRepositoryImpl(
      store: store,
      currentUser: () => DemoData.parkManager,
    );

    await expectLater(
      repo.generateReport(testCriteria(parkId: 'PARK-OTHER')),
      throwsA(isA<PermissionException>()),
    );
    expect(store.loads, 0);
  });

  test('invalid filters do not query report data', () async {
    final store = MemoryReportReadStore(const ReportSourceData());
    final repo = ReportRepositoryImpl(
      store: store,
      currentUser: () => DemoData.parkManager,
    );

    await expectLater(
      repo.generateReport(
        testCriteria(
          start: DateTime.utc(2026, 5, 2),
          end: DateTime.utc(2026, 5, 1),
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      repo.generateReport(testCriteria(categories: const [])),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.message,
          'message',
          ReportMessages.missingCategories,
        ),
      ),
    );
    expect(store.loads, 0);
  });

  test('a data-service failure does not create a report', () async {
    final store = MemoryReportReadStore(
      const ReportSourceData(),
      failure: dataServiceDown,
    );
    final repo = ReportRepositoryImpl(
      store: store,
      currentUser: () => DemoData.researcher,
    );

    await expectLater(
      repo.generateReport(testCriteria()),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('22. generating again does not mutate the previous snapshot', () async {
    final store = MemoryReportReadStore(
      ReportSourceData(
        incidents: [
          testIncident(id: 'a'),
          testIncident(id: 'b', category: IncidentCategory.other),
        ],
      ),
    );
    var n = 0;
    final repo = ReportRepositoryImpl(
      store: store,
      currentUser: () => DemoData.parkManager,
      now: () => DateTime.utc(2026, 4, 1),
      newSnapshotId: () => 'snap-${n++}',
    );

    final first = await repo.generateReport(
      testCriteria(categories: const [IncidentCategory.snare]),
    );
    final frozen = first.toMap();
    final second = await repo.generateReport(testCriteria());

    expect(first.toMap(), frozen);
    expect(first.totalIncidents, 1);
    expect(second.totalIncidents, 2);
    expect(identical(first, second), isFalse);
  });
}

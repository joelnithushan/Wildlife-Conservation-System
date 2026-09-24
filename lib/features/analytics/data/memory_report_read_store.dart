import '../domain/report_source_data.dart';
import 'report_read_store.dart';

/// In-memory read store for tests and for runs with no remote alert source.
class MemoryReportReadStore implements ReportReadStore {
  MemoryReportReadStore(this.data, {this.failure});

  final ReportSourceData data;
  final Object? failure;
  int loads = 0;

  @override
  Future<ReportSourceData> load(String parkId) async {
    loads++;
    final failure = this.failure;
    if (failure != null) throw failure;
    return data;
  }
}

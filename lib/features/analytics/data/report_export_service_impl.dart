import 'dart:convert';

import '../../../shared/models/conservation_report.dart';
import '../../../shared/repositories/report_export_service.dart';
import 'report_document_builder.dart';
import 'report_file_saver.dart';

/// Writes a PDF or CSV from an existing [ConservationReport].
///
/// The saver is injectable so tests do not touch the filesystem. Export never
/// calls [ReportRepository.generateReport].
typedef ReportFileSaver = Future<String> Function(
  String fileName,
  List<int> bytes,
);

class ReportExportServiceImpl implements ReportExportService {
  ReportExportServiceImpl({ReportFileSaver? save})
      : _save = save ?? saveReportBytes;

  final ReportFileSaver _save;

  @override
  Future<String> exportPdf(ConservationReport report) async {
    final bytes = await buildReportPdfBytes(report);
    return _save(_fileName(report, 'pdf'), bytes);
  }

  @override
  Future<String> exportCsv(ConservationReport report) async {
    final csv = buildReportCsv(report);
    return _save(_fileName(report, 'csv'), utf8.encode(csv));
  }

  static String _fileName(ConservationReport report, String extension) {
    final id = report.snapshotId.isEmpty ? 'unsaved' : report.snapshotId;
    return 'conservation-$id.$extension';
  }
}

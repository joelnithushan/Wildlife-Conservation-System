import '../models/conservation_report.dart';

/// Contract for exporting a generated report. Implementations (pdf/csv) are
/// added on the UC04 feature branch — this only fixes the interface so callers
/// can depend on it now.
abstract interface class ReportExportService {
  /// Returns the path/URI of the generated PDF file.
  Future<String> exportPdf(ConservationReport report);

  /// Returns the path/URI of the generated CSV file.
  Future<String> exportCsv(ConservationReport report);
}

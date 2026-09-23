import '../models/conservation_report.dart';
import '../models/report_criteria.dart';

/// Contract for UC04 – Analyze Conservation Data and Generate Reports.
/// Implementations read patrol/incident/response records (UC01–UC03) and
/// aggregate — there is no separate analytics database.
abstract interface class ReportRepository {
  Future<ConservationReport> generateReport(ReportCriteria criteria);
}

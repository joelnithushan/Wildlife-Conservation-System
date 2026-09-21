import '../entities/report_filter.dart';

abstract class AnalyticsRepository {
  Future<int> getTotalPatrols(ReportFilter filter);
  Future<int> getTotalIncidents(ReportFilter filter);
  Future<int> getTotalAlerts(ReportFilter filter);
  Future<Map<String, int>> getIncidentsByCategory(ReportFilter filter);
  Future<Map<String, int>> getAlertsByStatus(ReportFilter filter);
  Future<double> getPatrolCoverageKm(ReportFilter filter);
}

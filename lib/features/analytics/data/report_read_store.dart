import '../../../shared/models/wildlife_risk_alert.dart';
import '../domain/report_source_data.dart';

/// Read-only access to patrol, incident, and alert records for UC04.
///
/// Implementations must not insert, update, or delete source records.
abstract interface class ReportReadStore {
  Future<ReportSourceData> load(String parkId);
}

/// Read-only access to wildlife risk alerts (UC03). Alerts are online-first
/// and are not stored in the local patrol/incident database.
abstract interface class AlertReadStore {
  Future<List<WildlifeRiskAlert>> load(String parkId);
}

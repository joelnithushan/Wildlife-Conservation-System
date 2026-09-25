import '../../../shared/models/incident_report.dart';
import '../../../shared/models/patrol.dart';
import '../../../shared/models/patrol_position.dart';
import '../../../shared/models/wildlife_risk_alert.dart';

/// One read-only load of the records a report may aggregate.
///
/// The repository asks for this once per generation. Aggregation and export
/// never issue another query.
class ReportSourceData {
  const ReportSourceData({
    this.patrols = const [],
    this.positions = const [],
    this.incidents = const [],
    this.alerts = const [],
  });

  final List<Patrol> patrols;
  final List<PatrolPosition> positions;
  final List<IncidentReport> incidents;
  final List<WildlifeRiskAlert> alerts;
}

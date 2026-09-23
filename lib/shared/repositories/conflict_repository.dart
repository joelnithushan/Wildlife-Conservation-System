import '../models/app_user.dart';
import '../models/community_report.dart';
import '../models/location_reading.dart';
import '../models/response_assignment.dart';
import '../models/wildlife_risk_alert.dart';

/// Contract for UC03 – Coordinate Wildlife Conflict Response.
abstract interface class ConflictRepository {
  /// Ingest a collar reading; may raise an alert if it enters a risk zone.
  Future<WildlifeRiskAlert?> processLocationReading(LocationReading reading);

  /// Ingest a community report; may raise an alert.
  Future<WildlifeRiskAlert?> processCommunityReport(CommunityReport report);

  Future<List<WildlifeRiskAlert>> getAlerts(String parkId);
  Future<WildlifeRiskAlert?> getAlert(String id);

  Future<List<AppUser>> getAvailableResponders(String parkId);
  Future<ResponseAssignment> assignResponder({
    required String alertId,
    required String responderId,
    required String assignedBy,
  });
  Future<ResponseAssignment> acknowledgeAssignment(String assignmentId);
  Future<ResponseAssignment> startResponse(String assignmentId);
  Future<ResponseAssignment> updateResponseStatus({
    required String assignmentId,
    required String statusNote,
  });
  Future<ResponseAssignment> recordOutcome({
    required String assignmentId,
    required String outcome,
  });
  Future<WildlifeRiskAlert> resolveAlert(String alertId);
}

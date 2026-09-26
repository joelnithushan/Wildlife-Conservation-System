import '../models/app_user.dart';
import '../models/community_report.dart';
import '../models/location_reading.dart';
import '../models/response_assignment.dart';
import '../models/risk_zone.dart';
import '../models/tracked_animal.dart';
import '../models/wildlife_risk_alert.dart';

/// Contract for UC03 – Coordinate Wildlife Conflict Response.
///
/// UC03 needs richer read access than the original draft (community reports,
/// per-alert assignment history, responder identity on acknowledgement) so the
/// manager and responder screens can render the full lifecycle. Implementations
/// must keep IDs stable and never create duplicate records on retries.
abstract interface class ConflictRepository {
  // --- Triggers -------------------------------------------------------------

  /// Ingest a collar reading (Trigger A); may raise/refresh an alert if it
  /// enters a risk zone. Returns the affected alert, or null when no alert.
  Future<WildlifeRiskAlert?> processLocationReading(LocationReading reading);

  /// Ingest a *verified* community report (Trigger B); may raise/refresh an
  /// alert. Unverified reports never raise an alert.
  Future<WildlifeRiskAlert?> processCommunityReport(CommunityReport report);

  // --- Reference/read data --------------------------------------------------

  Future<List<WildlifeRiskAlert>> getAlerts(String parkId);
  Future<WildlifeRiskAlert?> getAlert(String id);
  Future<List<RiskZone>> getRiskZones(String parkId);
  Future<List<TrackedAnimal>> getTrackedAnimals();

  // --- Community reports -----------------------------------------------------

  Future<List<CommunityReport>> getCommunityReports(String parkId);

  /// Mark a report credible; returns the updated report. Verifying then feeds
  /// the same alert-response workflow via [processCommunityReport].
  Future<CommunityReport> verifyCommunityReport({
    required String reportId,
    required String verifiedBy,
  });

  // --- Responders & assignments ---------------------------------------------

  Future<List<AppUser>> getAvailableResponders(String parkId);
  Future<List<ResponseAssignment>> getAssignmentsForAlert(String alertId);

  /// The most recent assignment for an alert (the one currently in play), or
  /// null if none has been made.
  Future<ResponseAssignment?> getActiveAssignment(String alertId);
  Future<ResponseAssignment?> getAssignment(String assignmentId);

  Future<ResponseAssignment> assignResponder({
    required String alertId,
    required String responderId,
    required String assignedBy,
  });

  /// Only the assigned responder may acknowledge their own assignment.
  Future<ResponseAssignment> acknowledgeAssignment({
    required String assignmentId,
    required String responderId,
  });

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

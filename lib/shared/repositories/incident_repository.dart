import '../../core/enums/app_enums.dart';
import '../models/incident_report.dart';

/// Contract for UC02 – Record and Review Wildlife Incidents.
abstract interface class IncidentRepository {
  List<IncidentCategory> getCategories();
  Future<IncidentReport> createIncident(IncidentReport draft);
  Future<IncidentReport> submitIncident(String id);
  Future<List<IncidentReport>> getPendingIncidents();
  Future<List<IncidentReport>> getIncidentsForReview(String parkId);
  Future<IncidentReport?> getIncident(String id);
  Future<IncidentReport> updateReviewStatus({
    required String id,
    required ReviewStatus status,
    required String reviewerId,
    String? reviewNotes,
  });
}

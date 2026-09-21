import '../entities/conflict_response.dart';
import '../entities/wildlife_risk_alert.dart';

abstract class ConflictResponseRepository {
  Future<List<WildlifeRiskAlert>> getActiveAlerts();
  Future<WildlifeRiskAlert?> getAlertById(String id);
  Future<void> saveAlert(WildlifeRiskAlert alert);
  Future<void> updateAlertStatus(String id, String status);
  Future<void> assignResponder(String alertId, String responderId);
  Future<void> saveResponse(ConflictResponse response);
  Future<ConflictResponse?> getResponseForAlert(String alertId);
  Future<void> updateResponseStatus(String id, String status);
}

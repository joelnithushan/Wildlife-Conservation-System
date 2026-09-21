import '../entities/wildlife_incident.dart';

abstract class IncidentRepository {
  Future<List<WildlifeIncident>> getIncidents({String? rangerId});
  Future<WildlifeIncident?> getIncidentById(String id);
  Future<void> saveIncident(WildlifeIncident incident);
  Future<void> updateIncidentStatus(String id, String status);
  Future<List<WildlifeIncident>> getPendingSyncIncidents();
}

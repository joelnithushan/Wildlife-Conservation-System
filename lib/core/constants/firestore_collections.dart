/// Central registry of Firestore collection names.
///
/// Never hardcode collection strings elsewhere — reference these constants so a
/// rename happens in one place and typos become compile errors.
abstract final class FirestoreCollections {
  static const users = 'users';
  static const parks = 'parks';
  static const patrolRoutes = 'patrol_routes';
  static const patrols = 'patrols';
  static const patrolPositions = 'patrol_positions';
  static const incidentReports = 'incident_reports';
  static const riskZones = 'risk_zones';
  static const trackedAnimals = 'tracked_animals';
  static const locationReadings = 'location_readings';
  static const wildlifeRiskAlerts = 'wildlife_risk_alerts';
  static const responseAssignments = 'response_assignments';
  static const communityReports = 'community_reports';
}

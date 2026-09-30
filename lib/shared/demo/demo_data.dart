import '../../core/enums/app_enums.dart';
import '../models/app_user.dart';
import '../models/community_report.dart';
import '../models/geo_coordinate.dart';
import '../models/park.dart';
import '../models/patrol_route.dart';
import '../models/risk_zone.dart';
import '../models/tracked_animal.dart';
import '../models/wildlife_risk_alert.dart';

/// Development/demo seed data. Pure in-memory constants — this NEVER writes to
/// or deletes from Firebase. A seeding mechanism can push these into the local
/// DB or an emulator during development only.
abstract final class DemoData {
  // --- Park ---
  static const park = Park(id: 'PARK-MIN', name: 'Minneriya National Park');
  static String get parkId => park.id;

  // --- Users ---
  static const parkManager = AppUser(
    id: 'PM001',
    name: 'Park Manager',
    email: 'manager@wildguard.lk',
    role: UserRole.parkManager,
    parkId: 'PARK-MIN',
  );

  static const rangerPerera = AppUser(
    id: 'R001',
    name: 'K. Perera',
    email: 'ranger1@wildguard.lk',
    role: UserRole.ranger,
    parkId: 'PARK-MIN',
  );

  static const rangerSilva = AppUser(
    id: 'R002',
    name: 'R. Silva',
    email: 'ranger2@wildguard.lk',
    role: UserRole.ranger,
    parkId: 'PARK-MIN',
  );

  static const liaisonOfficer = AppUser(
    id: 'CLO001',
    name: 'S. Nimal',
    email: 'clo@wildguard.lk',
    role: UserRole.communityLiaisonOfficer,
    parkId: 'PARK-MIN',
  );

  static const researcher = AppUser(
    id: 'CR001',
    name: 'Conservation Researcher',
    email: 'researcher@wildguard.lk',
    role: UserRole.conservationResearcher,
    parkId: 'PARK-MIN',
  );

  static const users = <AppUser>[
    parkManager,
    rangerPerera,
    rangerSilva,
    liaisonOfficer,
    researcher,
  ];

  // --- Patrol routes ---
  // Planned paths are a handful of waypoints (centred near Minneriya) so patrol
  // coverage can be demonstrated. Real routes would carry a denser path.
  static const routes = <PatrolRoute>[
    PatrolRoute(
      id: 'RT-07',
      parkId: 'PARK-MIN',
      name: 'North Ridge',
      description: 'Northern ridge line patrol.',
      distanceKm: 7.4,
      plannedPath: [
        GeoCoordinate(latitude: 8.030, longitude: 80.890),
        GeoCoordinate(latitude: 8.040, longitude: 80.895),
        GeoCoordinate(latitude: 8.050, longitude: 80.900),
        GeoCoordinate(latitude: 8.060, longitude: 80.905),
        GeoCoordinate(latitude: 8.070, longitude: 80.910),
      ],
    ),
    PatrolRoute(
      id: 'RT-05',
      parkId: 'PARK-MIN',
      name: 'River Loop',
      description: 'Loop following the river bank.',
      distanceKm: 5.1,
      plannedPath: [
        GeoCoordinate(latitude: 8.010, longitude: 80.870),
        GeoCoordinate(latitude: 8.015, longitude: 80.880),
        GeoCoordinate(latitude: 8.020, longitude: 80.885),
        GeoCoordinate(latitude: 8.015, longitude: 80.892),
      ],
    ),
    PatrolRoute(
      id: 'RT-02',
      parkId: 'PARK-MIN',
      name: 'Gate Circuit',
      description: 'Short circuit around the main gate.',
      distanceKm: 3.8,
      plannedPath: [
        GeoCoordinate(latitude: 7.995, longitude: 80.860),
        GeoCoordinate(latitude: 8.000, longitude: 80.865),
        GeoCoordinate(latitude: 8.003, longitude: 80.868),
      ],
    ),
  ];

  // --- Risk zones ---
  // Each zone carries a small rectangular boundary polygon near Minneriya so the
  // point-in-polygon risk check is meaningful in demos and tests. Points are
  // (lat, lon) corners walked clockwise.
  static const riskZones = <RiskZone>[
    RiskZone(
      id: 'RZ-01',
      parkId: 'PARK-MIN',
      name: 'Farmland East',
      riskLevel: RiskLevel.high,
      boundary: [
        GeoCoordinate(latitude: 8.020, longitude: 80.890),
        GeoCoordinate(latitude: 8.040, longitude: 80.890),
        GeoCoordinate(latitude: 8.040, longitude: 80.910),
        GeoCoordinate(latitude: 8.020, longitude: 80.910),
      ],
    ),
    RiskZone(
      id: 'RZ-02',
      parkId: 'PARK-MIN',
      name: 'Village Edge',
      riskLevel: RiskLevel.medium,
      boundary: [
        GeoCoordinate(latitude: 8.000, longitude: 80.860),
        GeoCoordinate(latitude: 8.020, longitude: 80.860),
        GeoCoordinate(latitude: 8.020, longitude: 80.880),
        GeoCoordinate(latitude: 8.000, longitude: 80.880),
      ],
    ),
    RiskZone(
      id: 'RZ-03',
      parkId: 'PARK-MIN',
      name: 'A11 Junction',
      riskLevel: RiskLevel.medium,
      boundary: [
        GeoCoordinate(latitude: 7.980, longitude: 80.850),
        GeoCoordinate(latitude: 8.000, longitude: 80.850),
        GeoCoordinate(latitude: 8.000, longitude: 80.870),
        GeoCoordinate(latitude: 7.980, longitude: 80.870),
      ],
    ),
  ];

  /// A coordinate guaranteed to sit inside [RZ-01] (Farmland East) — handy for
  /// simulating a collar reading that should raise an alert.
  static const insideRiskZonePoint =
      GeoCoordinate(latitude: 8.030, longitude: 80.900);

  /// A coordinate outside every configured risk zone.
  static const outsideRiskZonePoint =
      GeoCoordinate(latitude: 8.200, longitude: 81.200);

  // --- Tracked animals ---
  static const trackedAnimals = <TrackedAnimal>[
    TrackedAnimal(
      id: 'EL-07',
      code: 'EL-07',
      species: 'Elephant',
      collarId: 'COLLAR-EL07',
    ),
    TrackedAnimal(
      id: 'EL-09',
      code: 'EL-09',
      species: 'Elephant',
      collarId: 'COLLAR-EL09',
    ),
  ];

  // --- UC03 responders ---
  /// Responders for conflict response. One responder is marked unavailable to
  /// exercise the "responder not selectable / no responder available" paths.
  static List<AppUser> get conflictResponders => [
        rangerPerera,
        rangerSilva.copyWith(isAvailable: false),
        liaisonOfficer,
      ];

  // --- UC03 community reports (Trigger B) ---
  /// Static community reports. IDs are stable so verifying one never creates a
  /// duplicate. One sits inside a risk zone (credible), one outside it.
  static List<CommunityReport> get communityReports => [
        CommunityReport(
          id: 'community_demo_1',
          parkId: parkId,
          description: 'Elephant seen pushing against the village fence.',
          latitude: 8.010,
          longitude: 80.870,
          createdAt: DateTime.utc(2026, 9, 25, 6, 30),
        ),
        CommunityReport(
          id: 'community_demo_2',
          parkId: parkId,
          description: 'Distant sighting far from any settlement.',
          latitude: 8.200,
          longitude: 81.200,
          createdAt: DateTime.utc(2026, 9, 25, 5, 0),
        ),
      ];

  // --- UC03 seeded alerts ---
  /// Two open alerts so the Risk Alerts screen has data on first launch. Stable
  /// IDs and constructed via the plain constructor (not `create`) so they stay
  /// deterministic across runs and tests.
  static List<WildlifeRiskAlert> seededAlerts(DateTime now) => [
        WildlifeRiskAlert(
          id: 'alert_demo_collar',
          parkId: parkId,
          source: AlertSource.collar,
          latitude: 8.030,
          longitude: 80.900,
          severity: AlertSeverity.high,
          createdAt: now.subtract(const Duration(minutes: 8)),
          animalId: 'EL-07',
          riskZoneId: 'RZ-01',
        ),
        WildlifeRiskAlert(
          id: 'alert_demo_community',
          parkId: parkId,
          source: AlertSource.communityReport,
          latitude: 8.010,
          longitude: 80.870,
          severity: AlertSeverity.medium,
          createdAt: now.subtract(const Duration(minutes: 20)),
          riskZoneId: 'RZ-02',
        ),
      ];
}

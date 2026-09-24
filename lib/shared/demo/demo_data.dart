import '../../core/enums/app_enums.dart';
import '../models/app_user.dart';
import '../models/geo_coordinate.dart';
import '../models/park.dart';
import '../models/patrol_route.dart';
import '../models/risk_zone.dart';
import '../models/tracked_animal.dart';

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
    role: UserRole.parkManager,
    parkId: 'PARK-MIN',
  );

  static const rangerPerera = AppUser(
    id: 'R001',
    name: 'K. Perera',
    role: UserRole.ranger,
    parkId: 'PARK-MIN',
  );

  static const rangerSilva = AppUser(
    id: 'R002',
    name: 'R. Silva',
    role: UserRole.ranger,
    parkId: 'PARK-MIN',
  );

  static const liaisonOfficer = AppUser(
    id: 'CLO001',
    name: 'S. Nimal',
    role: UserRole.communityLiaisonOfficer,
    parkId: 'PARK-MIN',
  );

  static const researcher = AppUser(
    id: 'CR001',
    name: 'Conservation Researcher',
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
  static const riskZones = <RiskZone>[
    RiskZone(
      id: 'RZ-01',
      parkId: 'PARK-MIN',
      name: 'Farmland East',
      riskLevel: RiskLevel.high,
    ),
    RiskZone(
      id: 'RZ-02',
      parkId: 'PARK-MIN',
      name: 'Village Edge',
      riskLevel: RiskLevel.medium,
    ),
    RiskZone(
      id: 'RZ-03',
      parkId: 'PARK-MIN',
      name: 'A11 Junction',
      riskLevel: RiskLevel.medium,
    ),
  ];

  // --- Tracked animals ---
  static const trackedAnimals = <TrackedAnimal>[
    TrackedAnimal(
      id: 'EL-07',
      code: 'EL-07',
      species: 'Elephant',
      collarId: 'COLLAR-EL07',
    ),
  ];
}

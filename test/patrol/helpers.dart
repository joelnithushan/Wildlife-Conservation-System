import 'package:drift/native.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/shared/models/geo_coordinate.dart';
import 'package:wildlife_conservation_system/shared/models/patrol_route.dart';

/// Fresh in-memory database for each test.
AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

const testRoute = PatrolRoute(
  id: 'RT-07',
  parkId: 'PARK-MIN',
  name: 'North Ridge',
  description: 'test route',
  distanceKm: 7.4,
  plannedPath: [
    GeoCoordinate(latitude: 8.030, longitude: 80.890),
    GeoCoordinate(latitude: 8.040, longitude: 80.895),
  ],
);

PatrolRoute? testRouteResolver(String id) => id == testRoute.id ? testRoute : null;

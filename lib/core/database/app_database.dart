import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'connection/connection.dart';
import 'tables/alert_status_change_table.dart';
import 'tables/community_report_table.dart';
import 'tables/incident_report_table.dart';
import 'tables/location_reading_table.dart';
import 'tables/patrol_position_table.dart';
import 'tables/patrol_table.dart';
import 'tables/response_assignment_table.dart';
import 'tables/wildlife_risk_alert_table.dart';

part 'app_database.g.dart';

/// Offline-first local database. Backs field workflows (UC01 patrols, UC02
/// incidents) as well as UC03 conflict-coordination data (alerts, readings,
/// assignments, status history, community reports) so all operational data
/// survives app restarts.
@DriftDatabase(
  tables: [
    PatrolsTable,
    PatrolPositionsTable,
    IncidentReportsTable,
    WildlifeRiskAlertsTable,
    LocationReadingsTable,
    ResponseAssignmentsTable,
    AlertStatusChangesTable,
    CommunityReportsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(wildlifeRiskAlertsTable);
            await m.createTable(locationReadingsTable);
            await m.createTable(responseAssignmentsTable);
            await m.createTable(alertStatusChangesTable);
            await m.createTable(communityReportsTable);
          }
        },
      );
}

@riverpod
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

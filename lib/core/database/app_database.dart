import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'connection/connection.dart';
import 'tables/incident_report_table.dart';
import 'tables/patrol_position_table.dart';
import 'tables/patrol_table.dart';

part 'app_database.g.dart';

/// Offline-first local database. Intentionally limited to the tables needed for
/// field workflows that must work without coverage (UC01 patrols, UC02
/// incidents). Coordination data (alerts, assignments) is online-first and not
/// mirrored here.
@DriftDatabase(
  tables: [
    PatrolsTable,
    PatrolPositionsTable,
    IncidentReportsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 1;
}

@riverpod
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

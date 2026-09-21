import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tables/conflict_response_table.dart';
import 'tables/incident_table.dart';
import 'tables/patrol_position_table.dart';
import 'tables/patrol_table.dart';
import 'tables/risk_alert_table.dart';
import 'tables/user_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    UsersTable,
    PatrolsTable,
    PatrolPositionsTable,
    WildlifeIncidentsTable,
    WildlifeRiskAlertsTable,
    ConflictResponsesTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'wildlife_conservation.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

@riverpod
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

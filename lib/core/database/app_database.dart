import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

import 'package:drift/drift.dart';

class PatrolPositionsTable extends Table {
  @override
  String get tableName => 'patrol_positions';

  TextColumn get id => text()();
  TextColumn get patrolId => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get captureMode => text().withDefault(const Constant('gps'))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

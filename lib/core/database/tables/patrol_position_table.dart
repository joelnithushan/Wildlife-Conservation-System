import 'package:drift/drift.dart';

/// Offline mirror of a [PatrolPosition] waypoint (UC01).
class PatrolPositionsTable extends Table {
  @override
  String get tableName => 'patrol_positions';

  TextColumn get id => text()();
  TextColumn get patrolId => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get captureMode => text().withDefault(const Constant('gps'))();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

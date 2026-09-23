import 'package:drift/drift.dart';

/// Offline mirror of a [Patrol] for field workflows (UC01).
class PatrolsTable extends Table {
  @override
  String get tableName => 'patrols';

  TextColumn get id => text()();
  TextColumn get routeId => text()();
  TextColumn get rangerId => text()();
  TextColumn get parkId => text()();
  DateTimeColumn get scheduledFor => dateTime()();
  TextColumn get status => text().withDefault(const Constant('assigned'))();
  DateTimeColumn get assignedAt => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  RealColumn get coveragePercent => real().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

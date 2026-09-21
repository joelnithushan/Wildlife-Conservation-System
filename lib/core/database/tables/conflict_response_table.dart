import 'package:drift/drift.dart';

class ConflictResponsesTable extends Table {
  @override
  String get tableName => 'conflict_responses';

  TextColumn get id => text()();
  TextColumn get alertId => text()();
  TextColumn get responderId => text()();
  TextColumn get status => text().withDefault(const Constant('assigned'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get acknowledgedAt => dateTime().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

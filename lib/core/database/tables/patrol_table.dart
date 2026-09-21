import 'package:drift/drift.dart';

class PatrolsTable extends Table {
  @override
  String get tableName => 'patrols';

  TextColumn get id => text()();
  TextColumn get rangerId => text()();
  TextColumn get routeId => text().nullable()();
  TextColumn get routeName => text().nullable()();
  TextColumn get status => text()(); // PatrolStatus
  DateTimeColumn get startTime => dateTime().nullable()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

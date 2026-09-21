import 'package:drift/drift.dart';

class WildlifeIncidentsTable extends Table {
  @override
  String get tableName => 'wildlife_incidents';

  TextColumn get id => text()();
  TextColumn get rangerId => text()();
  TextColumn get patrolId => text().nullable()();
  TextColumn get category => text()(); // IncidentCategory
  TextColumn get description => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get localPhotoPath => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

import 'package:drift/drift.dart';

/// Offline mirror of a [LocationReading] (UC03).
class LocationReadingsTable extends Table {
  @override
  String get tableName => 'location_readings';

  TextColumn get id => text()();
  TextColumn get animalId => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get observedAt => dateTime()();
  DateTimeColumn get receivedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

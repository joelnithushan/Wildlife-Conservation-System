import 'package:drift/drift.dart';

class WildlifeRiskAlertsTable extends Table {
  @override
  String get tableName => 'wildlife_risk_alerts';

  TextColumn get id => text()();
  TextColumn get animalId => text().nullable()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get riskZoneId => text().nullable()();
  TextColumn get severity => text()(); // AlertSeverity
  TextColumn get status => text().withDefault(const Constant('newAlert'))();
  TextColumn get assignedResponderId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

import 'package:drift/drift.dart';

/// Offline mirror of a [WildlifeRiskAlert] (UC03).
class WildlifeRiskAlertsTable extends Table {
  @override
  String get tableName => 'wildlife_risk_alerts';

  TextColumn get id => text()();
  TextColumn get parkId => text()();
  TextColumn get animalId => text().nullable()();
  TextColumn get riskZoneId => text().nullable()();
  TextColumn get source => text()(); // AlertSource
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get severity => text()(); // AlertSeverity
  TextColumn get status => text().withDefault(const Constant('newAlert'))(); // AlertStatus
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

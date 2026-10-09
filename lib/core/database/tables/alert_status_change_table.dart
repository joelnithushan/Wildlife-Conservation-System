import 'package:drift/drift.dart';

/// Offline mirror of an [AlertStatusChange] (UC03).
class AlertStatusChangesTable extends Table {
  @override
  String get tableName => 'alert_status_changes';

  TextColumn get id => text()();
  TextColumn get alertId => text()();
  TextColumn get fromStatus => text().nullable()(); // AlertStatus
  TextColumn get toStatus => text()(); // AlertStatus
  TextColumn get changedBy => text().nullable()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

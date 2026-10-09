import 'package:drift/drift.dart';

/// Offline mirror of a [ResponseAssignment] (UC03).
class ResponseAssignmentsTable extends Table {
  @override
  String get tableName => 'response_assignments';

  TextColumn get id => text()();
  TextColumn get alertId => text()();
  TextColumn get responderId => text()();
  TextColumn get responderRole => text()(); // ResponderRole
  TextColumn get assignedBy => text()();
  DateTimeColumn get assignedAt => dateTime()();
  TextColumn get deliveryState =>
      text().withDefault(const Constant('pending'))(); // DeliveryState
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get acknowledgedAt => dateTime().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  TextColumn get statusNote => text().nullable()();
  TextColumn get outcome => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

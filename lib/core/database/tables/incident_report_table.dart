import 'package:drift/drift.dart';

/// Offline mirror of an [IncidentReport] (UC02).
class IncidentReportsTable extends Table {
  @override
  String get tableName => 'incident_reports';

  TextColumn get id => text()();
  TextColumn get rangerId => text()();
  TextColumn get patrolId => text().nullable()();
  TextColumn get parkId => text()();
  TextColumn get category => text()(); // IncidentCategory
  TextColumn get description => text()();
  DateTimeColumn get observedAt => dateTime()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get locationSource => text().withDefault(const Constant('gps'))();
  TextColumn get localPhotoPath => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get evidenceOmissionReason => text().nullable()();
  TextColumn get submissionStatus =>
      text().withDefault(const Constant('draft'))();
  TextColumn get reviewStatus =>
      text().withDefault(const Constant('pendingReview'))();
  TextColumn get reviewerId => text().nullable()();
  TextColumn get reviewNotes => text().nullable()();
  DateTimeColumn get reviewedAt => dateTime().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

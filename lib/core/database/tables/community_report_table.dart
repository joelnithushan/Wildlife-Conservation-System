import 'package:drift/drift.dart';

/// Offline mirror of a [CommunityReport] (UC03).
class CommunityReportsTable extends Table {
  @override
  String get tableName => 'community_reports';

  TextColumn get id => text()();
  TextColumn get parkId => text()();
  TextColumn get description => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get channel => text().withDefault(const Constant('APP'))();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  TextColumn get verifiedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

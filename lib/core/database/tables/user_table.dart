import 'package:drift/drift.dart';

class UsersTable extends Table {
  @override
  String get tableName => 'users';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get role => text()(); // UserRole enum stored as string
  TextColumn get email => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

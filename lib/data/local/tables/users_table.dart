import 'package:drift/drift.dart';

class UsersTable extends Table {
  @override
  String get tableName => 'users';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().withLength(min: 1, max: 100).unique()();
  TextColumn get passwordHash => text()();
  TextColumn get passwordSalt => text()();
  IntColumn get passwordIterations => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class SessionsTable extends Table {
  @override
  String get tableName => 'sessions';

  TextColumn get tokenHash => text()();
  IntColumn get userId => integer().references(UsersTable, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get revokedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {tokenHash};
}

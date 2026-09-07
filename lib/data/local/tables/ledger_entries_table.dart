import 'package:drift/drift.dart';
import 'customers_table.dart';
import 'invoices_table.dart';

class LedgerEntriesTable extends Table {
  @override
  String get tableName => 'ledger_entries';

  TextColumn get id => text()();
  IntColumn get customerId => integer().references(CustomersTable, #id)();
  TextColumn get type => text()();
  IntColumn get amount => integer()();
  TextColumn get direction => text()();
  DateTimeColumn get operationDate => dateTime()();
  TextColumn get description => text().nullable()();
  IntColumn get invoiceId =>
      integer().nullable().references(InvoicesTable, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get reversesEntryId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LedgerEntryAuditsTable extends Table {
  @override
  String get tableName => 'ledger_entry_audits';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get entryId => text()();
  TextColumn get action => text()();
  TextColumn get snapshot => text()();
  DateTimeColumn get createdAt => dateTime()();
}

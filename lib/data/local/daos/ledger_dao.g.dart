// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_dao.dart';

// ignore_for_file: type=lint
mixin _$LedgerDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomersTableTable get customersTable => attachedDatabase.customersTable;
  $InvoicesTableTable get invoicesTable => attachedDatabase.invoicesTable;
  $LedgerEntriesTableTable get ledgerEntriesTable =>
      attachedDatabase.ledgerEntriesTable;
  $LedgerEntryAuditsTableTable get ledgerEntryAuditsTable =>
      attachedDatabase.ledgerEntryAuditsTable;
  LedgerDaoManager get managers => LedgerDaoManager(this);
}

class LedgerDaoManager {
  final _$LedgerDaoMixin _db;
  LedgerDaoManager(this._db);
  $$CustomersTableTableTableManager get customersTable =>
      $$CustomersTableTableTableManager(
          _db.attachedDatabase, _db.customersTable);
  $$InvoicesTableTableTableManager get invoicesTable =>
      $$InvoicesTableTableTableManager(_db.attachedDatabase, _db.invoicesTable);
  $$LedgerEntriesTableTableTableManager get ledgerEntriesTable =>
      $$LedgerEntriesTableTableTableManager(
          _db.attachedDatabase, _db.ledgerEntriesTable);
  $$LedgerEntryAuditsTableTableTableManager get ledgerEntryAuditsTable =>
      $$LedgerEntryAuditsTableTableTableManager(
          _db.attachedDatabase, _db.ledgerEntryAuditsTable);
}

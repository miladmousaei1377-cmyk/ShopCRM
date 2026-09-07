import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/customers_table.dart';
import '../tables/invoices_table.dart';
import '../tables/ledger_entries_table.dart';

part 'ledger_dao.g.dart';

@DriftAccessor(
  tables: [
    LedgerEntriesTable,
    LedgerEntryAuditsTable,
    CustomersTable,
    InvoicesTable
  ],
)
class LedgerDao extends DatabaseAccessor<AppDatabase> with _$LedgerDaoMixin {
  LedgerDao(super.db);

  Stream<List<TypedResult>> watchEntries() {
    final query = select(ledgerEntriesTable).join([
      innerJoin(customersTable,
          customersTable.id.equalsExp(ledgerEntriesTable.customerId)),
      leftOuterJoin(invoicesTable,
          invoicesTable.id.equalsExp(ledgerEntriesTable.invoiceId)),
    ]);
    return (query
          ..orderBy([OrderingTerm.desc(ledgerEntriesTable.operationDate)]))
        .watch();
  }

  Future<List<LedgerEntriesTableData>> entriesForCustomer(int customerId) =>
      (select(ledgerEntriesTable)
            ..where((t) => t.customerId.equals(customerId))
            ..orderBy([(t) => OrderingTerm.desc(t.operationDate)]))
          .get();

  Future<LedgerEntriesTableData?> entryById(String id) =>
      (select(ledgerEntriesTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<LedgerEntriesTableData?> activeEntryForInvoice(int invoiceId) =>
      (select(ledgerEntriesTable)
            ..where(
                (t) => t.invoiceId.equals(invoiceId) & t.isActive.equals(true)))
          .getSingleOrNull();

  Future<int> customerBalance(int customerId) async {
    final rows = await (select(ledgerEntriesTable)
          ..where((t) => t.customerId.equals(customerId)))
        .get();
    return rows.fold<int>(
        0,
        (sum, row) =>
            sum + (row.direction == 'debit' ? row.amount : -row.amount));
  }

  Future<void> insertWithAudit(LedgerEntriesTableCompanion entry) async {
    await into(ledgerEntriesTable).insert(entry);
    final row = await entryById(entry.id.value);
    await _audit(row!, 'create');
    await _refreshCustomerBalance(row.customerId);
  }

  Future<void> updateManual(LedgerEntriesTableCompanion entry) async {
    final current = await entryById(entry.id.value);
    if (current == null || current.invoiceId != null) {
      throw StateError('سند متصل به فاکتور مستقیماً قابل ویرایش نیست');
    }
    await _audit(current, 'before_update');
    await update(ledgerEntriesTable).replace(entry);
    await _audit((await entryById(entry.id.value))!, 'update');
    await _refreshCustomerBalance(current.customerId);
  }

  Future<void> deleteManual(String id) async {
    final current = await entryById(id);
    if (current == null) return;
    if (current.invoiceId != null) {
      throw StateError('سند متصل به فاکتور باید ابطال شود');
    }
    await _audit(current, 'delete');
    await (delete(ledgerEntriesTable)..where((t) => t.id.equals(id))).go();
    await _refreshCustomerBalance(current.customerId);
  }

  Future<void> voidEntry(
      String id, LedgerEntriesTableCompanion reversal) async {
    final current = await entryById(id);
    if (current == null || !current.isActive) return;
    await _audit(current, 'void');
    await (update(ledgerEntriesTable)..where((t) => t.id.equals(id))).write(
      LedgerEntriesTableCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await into(ledgerEntriesTable).insert(reversal);
    await _audit((await entryById(reversal.id.value))!, 'reversal');
    await _refreshCustomerBalance(current.customerId);
  }

  Future<void> _refreshCustomerBalance(int customerId) async {
    final balance = await customerBalance(customerId);
    await (update(customersTable)..where((t) => t.id.equals(customerId))).write(
      CustomersTableCompanion(
        totalDebt: Value(balance.toDouble()),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> _audit(LedgerEntriesTableData row, String action) =>
      into(ledgerEntryAuditsTable)
          .insert(LedgerEntryAuditsTableCompanion.insert(
        entryId: row.id,
        action: action,
        snapshot: jsonEncode({
          'customerId': row.customerId,
          'type': row.type,
          'amount': row.amount,
          'direction': row.direction,
          'operationDate': row.operationDate.toIso8601String(),
          'description': row.description,
          'invoiceId': row.invoiceId,
          'isActive': row.isActive,
        }),
        createdAt: DateTime.now(),
      ));
}

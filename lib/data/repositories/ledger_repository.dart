import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../local/database.dart';
import '../../domain/models/ledger_entry.dart';

class LedgerRepository {
  final AppDatabase db;
  LedgerRepository(this.db);

  Stream<List<LedgerEntry>> watchEntries(LedgerFilter filter) =>
      db.ledgerDao.watchEntries().map((rows) {
        final mapped = rows.map((row) {
          final entry = row.readTable(db.ledgerEntriesTable);
          final customer = row.readTable(db.customersTable);
          final invoice = row.readTableOrNull(db.invoicesTable);
          return LedgerEntry(
            id: entry.id,
            customerId: customer.id,
            customerName: customer.name,
            customerPhone: customer.phone,
            type:
                LedgerEntryType.values.firstWhere((e) => e.name == entry.type),
            amount: entry.amount,
            direction: LedgerDirection.values
                .firstWhere((e) => e.name == entry.direction),
            operationDate: entry.operationDate,
            description: entry.description,
            invoiceId: entry.invoiceId,
            invoiceNumber: invoice?.invoiceNumber,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            isActive: entry.isActive,
            reversesEntryId: entry.reversesEntryId,
          );
        }).toList();

        final balances = <String, int>{};
        final running = <int, int>{};
        final chronological = [...mapped]
          ..sort((a, b) => a.operationDate.compareTo(b.operationDate));
        for (final entry in chronological) {
          // A voided entry remains part of the immutable financial history. Its
          // opposite reversal entry brings the balance back to the correct value.
          running[entry.customerId] =
              (running[entry.customerId] ?? 0) + entry.signedAmount;
          balances[entry.id] = running[entry.customerId] ?? 0;
        }
        var result = mapped
            .map((e) => LedgerEntry(
                  id: e.id,
                  customerId: e.customerId,
                  customerName: e.customerName,
                  customerPhone: e.customerPhone,
                  type: e.type,
                  amount: e.amount,
                  direction: e.direction,
                  operationDate: e.operationDate,
                  description: e.description,
                  invoiceId: e.invoiceId,
                  invoiceNumber: e.invoiceNumber,
                  createdAt: e.createdAt,
                  updatedAt: e.updatedAt,
                  isActive: e.isActive,
                  reversesEntryId: e.reversesEntryId,
                  balanceAfter: balances[e.id] ?? 0,
                ))
            .where((e) {
          final q = filter.query.trim().toLowerCase();
          return (q.isEmpty ||
                  e.customerName.toLowerCase().contains(q) ||
                  (e.customerPhone?.contains(q) ?? false)) &&
              (filter.customerId == null ||
                  e.customerId == filter.customerId) &&
              (filter.from == null ||
                  !e.operationDate.isBefore(filter.from!)) &&
              (filter.to == null ||
                  e.operationDate
                      .isBefore(filter.to!.add(const Duration(days: 1)))) &&
              (filter.direction == null || e.direction == filter.direction) &&
              (filter.hasInvoice == null ||
                  (e.invoiceId != null) == filter.hasInvoice);
        }).toList();
        result.sort((a, b) {
          final comparison = filter.sortByAmount
              ? a.amount.compareTo(b.amount)
              : a.operationDate.compareTo(b.operationDate);
          return filter.ascending ? comparison : -comparison;
        });
        return result;
      });

  Future<int> balanceForCustomer(int customerId) =>
      db.ledgerDao.customerBalance(customerId);

  Future<void> create({
    required int customerId,
    required LedgerEntryType type,
    required int amount,
    required LedgerDirection direction,
    required DateTime operationDate,
    String? description,
    int? invoiceId,
  }) async {
    if (amount <= 0) throw ArgumentError('مبلغ باید بزرگ‌تر از صفر باشد');
    final now = DateTime.now();
    await db.transaction(() => db.ledgerDao.insertWithAudit(
          LedgerEntriesTableCompanion.insert(
            id: const Uuid().v4(),
            customerId: customerId,
            type: type.name,
            amount: amount,
            direction: direction.name,
            operationDate: operationDate,
            description: Value(description),
            invoiceId: Value(invoiceId),
            createdAt: now,
            updatedAt: now,
          ),
        ));
  }

  Future<void> createCreditPurchase({
    required int customerId,
    required int amount,
    required int invoiceId,
  }) =>
      create(
        customerId: customerId,
        type: LedgerEntryType.creditPurchase,
        amount: amount,
        direction: LedgerDirection.debit,
        operationDate: DateTime.now(),
        description: 'خرید اعتباری',
        invoiceId: invoiceId,
      );

  Future<void> updateManual(
    LedgerEntry entry, {
    required LedgerEntryType type,
    required int amount,
    required LedgerDirection direction,
    required DateTime operationDate,
    String? description,
  }) async {
    final companion = LedgerEntriesTableCompanion(
      id: Value(entry.id),
      customerId: Value(entry.customerId),
      type: Value(type.name),
      amount: Value(amount),
      direction: Value(direction.name),
      operationDate: Value(operationDate),
      description: Value(description),
      invoiceId: Value(entry.invoiceId),
      createdAt: Value(entry.createdAt),
      updatedAt: Value(DateTime.now()),
      isActive: Value(entry.isActive),
      reversesEntryId: Value(entry.reversesEntryId),
    );
    await db.transaction(() => db.ledgerDao.updateManual(companion));
  }

  Future<void> deleteManual(String id) =>
      db.transaction(() => db.ledgerDao.deleteManual(id));

  Future<void> voidEntry(String id) async {
    final current = await db.ledgerDao.entryById(id);
    if (current == null || !current.isActive) return;
    final now = DateTime.now();
    final reversal = LedgerEntriesTableCompanion.insert(
      id: const Uuid().v4(),
      customerId: current.customerId,
      type: LedgerEntryType.reversal.name,
      amount: current.amount,
      direction: current.direction == LedgerDirection.debit.name
          ? LedgerDirection.credit.name
          : LedgerDirection.debit.name,
      operationDate: now,
      description: Value('ابطال سند ${current.id}'),
      invoiceId: Value(current.invoiceId),
      createdAt: now,
      updatedAt: now,
      reversesEntryId: Value(current.id),
    );
    await db.transaction(() => db.ledgerDao.voidEntry(id, reversal));
  }
}

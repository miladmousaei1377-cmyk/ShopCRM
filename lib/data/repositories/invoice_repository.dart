import 'package:drift/drift.dart';
import '../../data/local/database.dart';
import '../../domain/models/invoice.dart';
import '../../domain/models/invoice_item.dart';
import '../../domain/models/product.dart';
import 'ledger_repository.dart';

class InvoiceRepository {
  final AppDatabase _db;

  InvoiceRepository(this._db);

  Stream<List<Invoice>> watchInvoices() =>
      _db.invoicesDao.watchInvoices().asyncMap((rows) async {
        final List<Invoice> result = [];
        for (final row in rows) {
          final items = await _db.invoicesDao.getInvoiceItems(row.id);
          result.add(_mapToModel(row, items));
        }
        return result;
      });

  Future<List<Invoice>> getInvoices({int limit = 50, int offset = 0}) async {
    final rows =
        await _db.invoicesDao.getInvoices(limit: limit, offset: offset);
    final result = <Invoice>[];
    for (final row in rows) {
      final items = await _db.invoicesDao.getInvoiceItems(row.id);
      result.add(_mapToModel(row, items));
    }
    return result;
  }

  Future<Invoice?> findById(int id) async {
    final row = await _db.invoicesDao.findById(id);
    if (row == null) return null;
    final items = await _db.invoicesDao.getInvoiceItems(id);
    return _mapToModel(row, items);
  }

  Future<List<Invoice>> getRecentInvoices({int limit = 5}) async {
    final rows = await _db.invoicesDao.getRecentInvoices(limit: limit);
    final result = <Invoice>[];
    for (final row in rows) {
      final items = await _db.invoicesDao.getInvoiceItems(row.id);
      result.add(_mapToModel(row, items));
    }
    return result;
  }

  Stream<List<Invoice>> watchRecentInvoices({int limit = 5}) =>
      _db.invoicesDao.watchRecentInvoices(limit: limit).asyncMap((rows) async {
        final result = <Invoice>[];
        for (final row in rows) {
          final items = await _db.invoicesDao.getInvoiceItems(row.id);
          result.add(_mapToModel(row, items));
        }
        return result;
      });

  Future<List<Invoice>> getInvoicesByPeriod(DateTime from, DateTime to) async {
    final rows = await _db.invoicesDao.getInvoicesByPeriod(from, to);
    final result = <Invoice>[];
    for (final row in rows) {
      final items = await _db.invoicesDao.getInvoiceItems(row.id);
      result.add(_mapToModel(row, items));
    }
    return result;
  }

  Future<List<Invoice>> getCustomerInvoices(int customerId) async {
    final rows = await _db.invoicesDao.getCustomerInvoices(customerId);
    final result = <Invoice>[];
    for (final row in rows) {
      final items = await _db.invoicesDao.getInvoiceItems(row.id);
      result.add(_mapToModel(row, items));
    }
    return result;
  }

  Future<int> saveInvoice(Invoice invoice) async {
    final invoiceCompanion = InvoicesTableCompanion(
      id: invoice.id == 0 ? const Value.absent() : Value(invoice.id),
      serverId: Value(invoice.serverId),
      invoiceNumber: Value(invoice.invoiceNumber),
      customerId: Value(invoice.customerId),
      customerName: Value(invoice.customerName),
      userId: Value(invoice.userId),
      totalAmount: Value(invoice.totalAmount),
      discount: Value(invoice.discount),
      isDiscountPercent: Value(invoice.isDiscountPercent),
      tax: Value(invoice.tax),
      finalAmount: Value(invoice.finalAmount),
      paymentMethod: Value(invoice.paymentMethod.name),
      status: Value(invoice.status.name),
      notes: Value(invoice.notes),
      createdAt: Value(invoice.createdAt),
      syncStatus: Value(invoice.syncStatus.name),
    );

    final itemCompanions = invoice.items
        .map(
          (item) => InvoiceItemsTableCompanion(
            productId: Value(item.productId),
            productName: Value(item.productName),
            productBarcode: Value(item.productBarcode),
            quantity: Value(item.quantity),
            unitPrice: Value(item.unitPrice),
            discountPercent: Value(item.discountPercent),
            subtotal: Value(item.subtotal),
          ),
        )
        .toList();

    return await _db.invoicesDao
        .insertInvoiceWithItems(invoiceCompanion, itemCompanions);
  }

  Future<void> updateStatus(int id, InvoiceStatus status) async {
    await _db.transaction(() async {
      await _db.invoicesDao.updateStatus(id, status.name);
      if (status == InvoiceStatus.cancelled ||
          status == InvoiceStatus.refunded) {
        final ledger = await _db.ledgerDao.activeEntryForInvoice(id);
        if (ledger != null) await LedgerRepository(_db).voidEntry(ledger.id);
      }
    });
  }

  Future<double> getTodaySalesTotal() => _db.invoicesDao.getTodaySalesTotal();

  Invoice _mapToModel(
      InvoicesTableData row, List<InvoiceItemsTableData> itemRows) {
    return Invoice(
      id: row.id,
      serverId: row.serverId,
      invoiceNumber: row.invoiceNumber,
      customerId: row.customerId,
      customerName: row.customerName,
      userId: row.userId,
      items: itemRows
          .map((item) => InvoiceItem(
                id: item.id,
                invoiceId: item.invoiceId,
                productId: item.productId,
                productName: item.productName,
                productBarcode: item.productBarcode,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                discountPercent: item.discountPercent,
              ))
          .toList(),
      discount: row.discount,
      isDiscountPercent: row.isDiscountPercent,
      tax: row.tax,
      paymentMethod: PaymentMethod.values.firstWhere(
        (p) => p.name == row.paymentMethod,
        orElse: () => PaymentMethod.cash,
      ),
      status: InvoiceStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => InvoiceStatus.draft,
      ),
      notes: row.notes,
      createdAt: row.createdAt,
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == row.syncStatus,
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}

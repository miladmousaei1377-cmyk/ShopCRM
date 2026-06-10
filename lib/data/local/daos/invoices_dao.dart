import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/invoices_table.dart';
import '../tables/products_table.dart';
import '../tables/customers_table.dart';

part 'invoices_dao.g.dart';

// نتیجه join فاکتور با مشتری
class InvoiceWithCustomer {
  final InvoicesTableData invoice;
  final CustomersTableData? customer;
  InvoiceWithCustomer(this.invoice, this.customer);
}

@DriftAccessor(tables: [InvoicesTable, InvoiceItemsTable, CustomersTable, ProductsTable])
class InvoicesDao extends DatabaseAccessor<AppDatabase> with _$InvoicesDaoMixin {
  InvoicesDao(super.db);

  // ثبت فاکتور + آیتم‌ها در یک تراکنش
  Future<int> insertInvoiceWithItems(
    InvoicesTableCompanion invoice,
    List<InvoiceItemsTableCompanion> items,
  ) async {
    return await transaction(() async {
      final invoiceId = await into(invoicesTable).insert(invoice);
      for (final item in items) {
        await into(invoiceItemsTable).insert(item.copyWith(invoiceId: Value(invoiceId)));
      }
      return invoiceId;
    });
  }

  // فهرست فاکتورها
  Stream<List<InvoicesTableData>> watchInvoices({int limit = 50}) =>
      (select(invoicesTable)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(limit))
          .watch();

  Future<List<InvoicesTableData>> getInvoices({int limit = 50, int offset = 0}) =>
      (select(invoicesTable)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(limit, offset: offset))
          .get();

  // فاکتورهای امروز
  Future<List<InvoicesTableData>> getTodayInvoices() {
    final startOfDay = DateTime.now().copyWith(
      hour: 0, minute: 0, second: 0, millisecond: 0,
    );
    return (select(invoicesTable)
      ..where((t) => t.createdAt.isBiggerOrEqualValue(startOfDay))
      ..where((t) => t.status.equals('completed')))
        .get();
  }

  // فاکتورهای یک بازه زمانی
  Future<List<InvoicesTableData>> getInvoicesByPeriod(
    DateTime from,
    DateTime to,
  ) =>
      (select(invoicesTable)
        ..where((t) => t.createdAt.isBiggerOrEqualValue(from))
        ..where((t) => t.createdAt.isSmallerOrEqualValue(to))
        ..where((t) => t.status.equals('completed'))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  // فاکتور با شناسه
  Future<InvoicesTableData?> findById(int id) =>
      (select(invoicesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  // آیتم‌های یک فاکتور
  Future<List<InvoiceItemsTableData>> getInvoiceItems(int invoiceId) =>
      (select(invoiceItemsTable)
        ..where((t) => t.invoiceId.equals(invoiceId)))
          .get();

  // بروزرسانی وضعیت فاکتور
  Future<void> updateStatus(int id, String status) =>
      (update(invoicesTable)..where((t) => t.id.equals(id)))
          .write(InvoicesTableCompanion(status: Value(status)));

  // فاکتورهای pending
  Future<List<InvoicesTableData>> getPendingInvoices() =>
      (select(invoicesTable)..where((t) => t.syncStatus.equals('pending'))).get();

  // بروزرسانی sync
  Future<void> markAsSynced(int id, int serverId) =>
      (update(invoicesTable)..where((t) => t.id.equals(id)))
          .write(InvoicesTableCompanion(
            serverId: Value(serverId),
            syncStatus: const Value('synced'),
          ));

  // جمع فروش امروز
  Future<double> getTodaySalesTotal() async {
    final invoices = await getTodayInvoices();
    return invoices.fold(0.0, (sum, inv) => sum + inv.finalAmount);
  }

  // ۵ فاکتور آخر
  Future<List<InvoicesTableData>> getRecentInvoices({int limit = 5}) =>
      (select(invoicesTable)
        ..where((t) => t.status.equals('completed'))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(limit))
          .get();

  // فاکتورهای مشتری
  Future<List<InvoicesTableData>> getCustomerInvoices(int customerId) =>
      (select(invoicesTable)
        ..where((t) => t.customerId.equals(customerId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
}

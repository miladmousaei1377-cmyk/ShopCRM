import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/products_table.dart';
import 'tables/invoices_table.dart';
import 'tables/customers_table.dart';
import 'tables/inventory_table.dart';
import 'daos/products_dao.dart';
import 'daos/invoices_dao.dart';
import 'daos/customers_dao.dart';

part 'database.g.dart';

/// پایگاه داده اصلی برنامه (SQLite از طریق Drift)
///
/// تمام داده‌ها اول اینجا ذخیره می‌شوند (offline-first).
/// بعداً با سرور sync می‌شوند.
/// فایل دیتابیس: shop_crm_db.sqlite
@DriftDatabase(
  tables: [
    ProductsTable,
    InvoicesTable,
    InvoiceItemsTable,
    CustomersTable,
    InventoryLogsTable,
  ],
  daos: [
    ProductsDao,
    InvoicesDao,
    CustomersDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// نسخه schema — با هر تغییر ساختار جدول باید افزایش یابد
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // اولین نصب: ایجاد همه جداول
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // مایگریشن‌های آپدیت — در نسخه‌های بعدی اینجا اضافه می‌شود
      // مثال: if (from < 2) { await m.addColumn(productsTable, productsTable.newColumn); }
    },
  );

  /// باز کردن اتصال به فایل SQLite
  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'shop_crm_db');
  }
}

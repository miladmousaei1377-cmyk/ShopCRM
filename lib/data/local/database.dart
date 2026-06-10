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

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // مایگریشن‌های آینده اینجا
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'shop_crm_db');
  }
}

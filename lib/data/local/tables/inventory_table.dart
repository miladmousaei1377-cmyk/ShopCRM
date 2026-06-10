import 'package:drift/drift.dart';
import 'products_table.dart';

class InventoryLogsTable extends Table {
  @override
  String get tableName => 'inventory_logs';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(ProductsTable, #id)();
  // stockIn | stockOut | adjust | sale | refund
  TextColumn get type => text()();
  IntColumn get quantity => integer()();
  IntColumn get previousStock => integer()();
  IntColumn get newStock => integer()();
  TextColumn get reason => text().nullable()();
  IntColumn get invoiceId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

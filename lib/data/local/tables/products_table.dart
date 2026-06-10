import 'package:drift/drift.dart';

class ProductsTable extends Table {
  @override
  String get tableName => 'products';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get barcode => text().nullable().withLength(max: 50)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get categoryId => integer().nullable()();
  RealColumn get purchasePrice => real().withDefault(const Constant(0))();
  RealColumn get sellPrice => real().withDefault(const Constant(0))();
  IntColumn get stockQuantity => integer().withDefault(const Constant(0))();
  IntColumn get minStockAlert => integer().withDefault(const Constant(5))();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();
  // synced | pending | conflict
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}

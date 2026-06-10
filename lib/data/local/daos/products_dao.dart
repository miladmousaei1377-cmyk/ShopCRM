import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/products_table.dart';

part 'products_dao.g.dart';

@DriftAccessor(tables: [ProductsTable])
class ProductsDao extends DatabaseAccessor<AppDatabase> with _$ProductsDaoMixin {
  ProductsDao(super.db);

  // همه محصولات فعال
  Future<List<ProductsTableData>> getAllProducts() =>
      (select(productsTable)..where((t) => t.isActive.equals(true))).get();

  // جریان محصولات فعال (watch برای UI)
  Stream<List<ProductsTableData>> watchAllProducts() =>
      (select(productsTable)..where((t) => t.isActive.equals(true))).watch();

  // جستجو بر اساس نام یا بارکد
  Stream<List<ProductsTableData>> watchProductsBySearch(String query) {
    final q = '%$query%';
    return (select(productsTable)
      ..where((t) =>
          t.name.like(q) |
          t.barcode.like(q))
      ..where((t) => t.isActive.equals(true)))
        .watch();
  }

  // پیدا کردن با بارکد
  Future<ProductsTableData?> findByBarcode(String barcode) =>
      (select(productsTable)..where((t) => t.barcode.equals(barcode))).getSingleOrNull();

  // پیدا کردن با ID
  Future<ProductsTableData?> findById(int id) =>
      (select(productsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  // محصولات زیر حداقل موجودی
  Future<List<ProductsTableData>> getLowStockProducts() =>
      (select(productsTable)
        ..where((t) => t.isActive.equals(true))
        ..where((t) => t.stockQuantity.isSmallerOrEqualValue(0) | t.stockQuantity.isSmallerThanExp(t.minStockAlert)))
          .get();

  Stream<List<ProductsTableData>> watchLowStockProducts() =>
      (select(productsTable)
        ..where((t) => t.isActive.equals(true))
        ..where((t) => t.stockQuantity.isSmallerOrEqualValue(0)))
          .watch();

  // درج محصول جدید
  Future<int> insertProduct(ProductsTableCompanion product) =>
      into(productsTable).insert(product);

  // بروزرسانی محصول
  Future<bool> updateProduct(ProductsTableCompanion product) =>
      update(productsTable).replace(product);

  // بروزرسانی موجودی
  Future<void> updateStock(int productId, int newStock) =>
      (update(productsTable)..where((t) => t.id.equals(productId)))
          .write(ProductsTableCompanion(
            stockQuantity: Value(newStock),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value('pending'),
          ));

  // حذف (غیرفعال کردن)
  Future<void> deactivateProduct(int id) =>
      (update(productsTable)..where((t) => t.id.equals(id)))
          .write(ProductsTableCompanion(
            isActive: const Value(false),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value('pending'),
          ));

  // همه محصولات pending برای sync
  Future<List<ProductsTableData>> getPendingProducts() =>
      (select(productsTable)..where((t) => t.syncStatus.equals('pending'))).get();

  // بروزرسانی syncStatus
  Future<void> markAsSynced(int id, int serverId) =>
      (update(productsTable)..where((t) => t.id.equals(id)))
          .write(ProductsTableCompanion(
            serverId: Value(serverId),
            syncStatus: const Value('synced'),
          ));

  // تعداد کل محصولات
  Future<int> getProductCount() async {
    final count = productsTable.id.count();
    final query = selectOnly(productsTable)
      ..addColumns([count])
      ..where(productsTable.isActive.equals(true));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}

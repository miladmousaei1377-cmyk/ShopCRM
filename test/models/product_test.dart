import 'package:flutter_test/flutter_test.dart';
import 'package:shop_crm/domain/models/product.dart';

Product _makeProduct({
  int id = 1,
  double purchasePrice = 50000,
  double sellPrice = 80000,
  int stock = 10,
  int minStock = 5,
}) =>
    Product(
      id: id,
      name: 'محصول آزمایشی',
      purchasePrice: purchasePrice,
      sellPrice: sellPrice,
      stockQuantity: stock,
      minStockAlert: minStock,
      updatedAt: DateTime(2024, 1, 15),
    );

void main() {
  group('Product', () {
    group('محاسبات', () {
      test('isLowStock وقتی موجودی <= حداقل true است', () {
        final p = _makeProduct(stock: 5, minStock: 5);
        expect(p.isLowStock, isTrue);
      });

      test('isLowStock وقتی موجودی بیشتر از حداقل false است', () {
        final p = _makeProduct(stock: 6, minStock: 5);
        expect(p.isLowStock, isFalse);
      });

      test('profitMargin درصد سود را محاسبه می‌کند', () {
        final p = _makeProduct(purchasePrice: 50000, sellPrice: 100000);
        expect(p.profitMargin, closeTo(50.0, 0.01));
      });

      test('profitMargin با قیمت فروش صفر برابر صفر است', () {
        final p = _makeProduct(sellPrice: 0);
        expect(p.profitMargin, 0.0);
      });

      test('profit مبلغ سود را برمی‌گرداند', () {
        final p = _makeProduct(purchasePrice: 60000, sellPrice: 100000);
        expect(p.profit, 40000.0);
      });
    });

    group('copyWith', () {
      test('فیلد مشخص شده را تغییر می‌دهد', () {
        final original = _makeProduct(stock: 10);
        final updated = original.copyWith(stockQuantity: 20);
        expect(updated.stockQuantity, 20);
        expect(updated.id, original.id);
        expect(updated.name, original.name);
      });

      test('بقیه فیلدها بدون تغییر می‌مانند', () {
        final original = _makeProduct();
        final updated = original.copyWith(sellPrice: 120000);
        expect(updated.purchasePrice, original.purchasePrice);
        expect(updated.stockQuantity, original.stockQuantity);
      });
    });

    group('toJson / fromJson', () {
      test('تبدیل به JSON و برگشت به مدل درست است', () {
        final p = _makeProduct();
        final json = p.toJson();
        final restored = Product.fromJson({
          ...json,
          'id': 1,
          'updated_at': DateTime(2024, 1, 15).toIso8601String(),
        });
        expect(restored.name, p.name);
        expect(restored.sellPrice, p.sellPrice);
        expect(restored.purchasePrice, p.purchasePrice);
        expect(restored.stockQuantity, p.stockQuantity);
        // از سرور برگشت = synced
        expect(restored.syncStatus, SyncStatus.synced);
      });

      test('toJson فیلدهای لازم را دارد', () {
        final p = _makeProduct();
        final json = p.toJson();
        expect(json.containsKey('name'), isTrue);
        expect(json.containsKey('sell_price'), isTrue);
        expect(json.containsKey('stock_quantity'), isTrue);
        expect(json.containsKey('updated_at'), isTrue);
      });
    });

    group('SyncStatus', () {
      test('مقدار پیش‌فرض pending است', () {
        final p = _makeProduct();
        expect(p.syncStatus, SyncStatus.pending);
      });
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/database.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/models/product.dart';

// دیتابیس singleton
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(databaseProvider));
});

// جستجوی فعال
final productSearchQueryProvider = StateProvider<String>((ref) => '');

// استریم محصولات با فیلتر جستجو
final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  final query = ref.watch(productSearchQueryProvider);
  return repo.watchProducts(search: query.isEmpty ? null : query);
});

// محصولات زیر حداقل موجودی
final lowStockProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).getLowStockProducts();
});

// یک محصول خاص
final productByIdProvider = FutureProvider.family<Product?, int>((ref, id) {
  return ref.watch(productRepositoryProvider).findById(id);
});

// پیدا کردن با بارکد
final productByBarcodeProvider = FutureProvider.family<Product?, String>((ref, barcode) {
  return ref.watch(productRepositoryProvider).findByBarcode(barcode);
});

// CRUD state
class ProductFormState {
  final bool isLoading;
  final String? error;
  final bool isDone;

  const ProductFormState({
    this.isLoading = false,
    this.error,
    this.isDone = false,
  });

  ProductFormState copyWith({bool? isLoading, String? error, bool? isDone}) {
    return ProductFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isDone: isDone ?? this.isDone,
    );
  }
}

class ProductFormNotifier extends StateNotifier<ProductFormState> {
  final ProductRepository _repo;

  ProductFormNotifier(this._repo) : super(const ProductFormState());

  Future<bool> save(Product product) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.saveProduct(product);
      state = state.copyWith(isLoading: false, isDone: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'خطا در ذخیره محصول: $e');
      return false;
    }
  }

  Future<bool> delete(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.deleteProduct(id);
      state = state.copyWith(isLoading: false, isDone: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'خطا در حذف محصول');
      return false;
    }
  }

  void reset() => state = const ProductFormState();
}

final productFormProvider = StateNotifierProvider.autoDispose<ProductFormNotifier, ProductFormState>((ref) {
  return ProductFormNotifier(ref.watch(productRepositoryProvider));
});

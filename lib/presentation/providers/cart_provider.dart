import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/invoice.dart';
import '../../domain/models/invoice_item.dart';
import '../../domain/models/product.dart';
import '../../domain/models/customer.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/customer_repository.dart';
import 'product_provider.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(databaseProvider));
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(databaseProvider));
});

class CartState {
  final List<InvoiceItem> items;
  final Customer? customer;
  final double discount;
  final bool isDiscountPercent;
  final double tax;
  final PaymentMethod paymentMethod;
  final bool isSubmitting;
  final String? error;
  final int? lastInvoiceId;

  const CartState({
    this.items = const [],
    this.customer,
    this.discount = 0,
    this.isDiscountPercent = false,
    this.tax = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.isSubmitting = false,
    this.error,
    this.lastInvoiceId,
  });

  double get totalAmount => items.fold(0, (sum, item) => sum + item.subtotal);

  double get discountAmount {
    if (isDiscountPercent) return totalAmount * discount / 100;
    return discount;
  }

  double get taxAmount => (totalAmount - discountAmount) * tax / 100;
  double get finalAmount => totalAmount - discountAmount + taxAmount;
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<InvoiceItem>? items,
    Customer? customer,
    bool clearCustomer = false,
    double? discount,
    bool? isDiscountPercent,
    double? tax,
    PaymentMethod? paymentMethod,
    bool? isSubmitting,
    String? error,
    int? lastInvoiceId,
  }) {
    return CartState(
      items: items ?? this.items,
      customer: clearCustomer ? null : (customer ?? this.customer),
      discount: discount ?? this.discount,
      isDiscountPercent: isDiscountPercent ?? this.isDiscountPercent,
      tax: tax ?? this.tax,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      lastInvoiceId: lastInvoiceId ?? this.lastInvoiceId,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  final InvoiceRepository _invoiceRepo;
  final ProductRepository _productRepo;
  final CustomerRepository _customerRepo;

  CartNotifier(this._invoiceRepo, this._productRepo, this._customerRepo)
      : super(const CartState());

  void addProduct(Product product, {int quantity = 1}) {
    final existing = state.items.indexWhere((i) => i.productId == product.id);
    if (existing >= 0) {
      final updated = List<InvoiceItem>.from(state.items);
      updated[existing] = state.items[existing].copyWith(
        quantity: state.items[existing].quantity + quantity,
      );
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [...state.items, InvoiceItem.fromProduct(product, quantity: quantity)],
      );
    }
  }

  void removeItem(int productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.productId != productId).toList(),
    );
  }

  void updateQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    final updated = state.items.map((i) {
      return i.productId == productId ? i.copyWith(quantity: quantity) : i;
    }).toList();
    state = state.copyWith(items: updated);
  }

  void incrementQuantity(int productId) {
    final item = state.items.firstWhere((i) => i.productId == productId);
    updateQuantity(productId, item.quantity + 1);
  }

  void decrementQuantity(int productId) {
    final item = state.items.firstWhere((i) => i.productId == productId);
    updateQuantity(productId, item.quantity - 1);
  }

  void setCustomer(Customer? customer) {
    if (customer == null) {
      state = state.copyWith(clearCustomer: true);
    } else {
      state = state.copyWith(customer: customer);
    }
  }

  void setDiscount(double value, {bool isPercent = false}) {
    state = state.copyWith(discount: value, isDiscountPercent: isPercent);
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setTax(double tax) {
    state = state.copyWith(tax: tax);
  }

  Future<int?> submitInvoice() async {
    if (state.items.isEmpty) return null;
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final invoice = Invoice(
        id: 0,
        invoiceNumber: _generateInvoiceNumber(),
        customerId: state.customer?.id,
        customerName: state.customer?.name,
        items: state.items,
        discount: state.discount,
        isDiscountPercent: state.isDiscountPercent,
        tax: state.tax,
        paymentMethod: state.paymentMethod,
        status: InvoiceStatus.completed,
        createdAt: DateTime.now(),
      );

      final id = await _invoiceRepo.saveInvoice(invoice);

      // کاهش موجودی محصولات
      for (final item in state.items) {
        final product = await _productRepo.findById(item.productId);
        if (product != null) {
          final newStock = product.stockQuantity - item.quantity;
          await _productRepo.updateStock(item.productId, newStock.clamp(0, 999999));
        }
      }

      // بدهی مشتری اگه نسیه بود
      if (state.paymentMethod == PaymentMethod.credit && state.customer != null) {
        final customer = state.customer!;
        await _customerRepo.updateDebt(
          customer.id,
          customer.totalDebt + invoice.finalAmount,
        );
      }

      state = state.copyWith(isSubmitting: false, lastInvoiceId: id);
      return id;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: 'خطا در ثبت فاکتور: $e');
      return null;
    }
  }

  void clearCart() {
    state = const CartState();
  }

  String _generateInvoiceNumber() {
    final now = DateTime.now();
    return 'INV-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${now.millisecondsSinceEpoch % 10000}';
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(
    ref.watch(invoiceRepositoryProvider),
    ref.watch(productRepositoryProvider),
    ref.watch(customerRepositoryProvider),
  );
});

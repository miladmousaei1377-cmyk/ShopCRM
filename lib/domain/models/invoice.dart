import 'package:equatable/equatable.dart';
import 'invoice_item.dart';
import 'product.dart';

enum PaymentMethod { cash, card, credit }

enum InvoiceStatus { draft, completed, cancelled, refunded }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash: return 'نقد';
      case PaymentMethod.card: return 'کارت';
      case PaymentMethod.credit: return 'نسیه';
    }
  }
}

extension InvoiceStatusLabel on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.draft: return 'پیش‌نویس';
      case InvoiceStatus.completed: return 'تکمیل شده';
      case InvoiceStatus.cancelled: return 'لغو شده';
      case InvoiceStatus.refunded: return 'مرجوع شده';
    }
  }
}

class Invoice extends Equatable {
  final int id;
  final int? serverId;
  final String invoiceNumber;
  final int? customerId;
  final String? customerName;
  final int? userId;
  final List<InvoiceItem> items;
  final double discount;
  final bool isDiscountPercent;
  final double tax;
  final PaymentMethod paymentMethod;
  final InvoiceStatus status;
  final String? notes;
  final DateTime createdAt;
  final SyncStatus syncStatus;

  const Invoice({
    required this.id,
    this.serverId,
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    this.userId,
    this.items = const [],
    this.discount = 0,
    this.isDiscountPercent = false,
    this.tax = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.status = InvoiceStatus.draft,
    this.notes,
    required this.createdAt,
    this.syncStatus = SyncStatus.pending,
  });

  double get totalAmount => items.fold(0, (sum, item) => sum + item.subtotal);

  double get discountAmount {
    if (isDiscountPercent) return totalAmount * discount / 100;
    return discount;
  }

  double get taxAmount => (totalAmount - discountAmount) * tax / 100;

  double get finalAmount => totalAmount - discountAmount + taxAmount;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Invoice copyWith({
    int? id,
    int? serverId,
    String? invoiceNumber,
    int? customerId,
    String? customerName,
    int? userId,
    List<InvoiceItem>? items,
    double? discount,
    bool? isDiscountPercent,
    double? tax,
    PaymentMethod? paymentMethod,
    InvoiceStatus? status,
    String? notes,
    DateTime? createdAt,
    SyncStatus? syncStatus,
  }) {
    return Invoice(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      discount: discount ?? this.discount,
      isDiscountPercent: isDiscountPercent ?? this.isDiscountPercent,
      tax: tax ?? this.tax,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'server_id': serverId,
    'invoice_number': invoiceNumber,
    'customer_id': customerId,
    'total_amount': totalAmount,
    'discount': discount,
    'is_discount_percent': isDiscountPercent,
    'tax': tax,
    'final_amount': finalAmount,
    'payment_method': paymentMethod.name,
    'status': status.name,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
  };

  @override
  List<Object?> get props => [id, invoiceNumber, finalAmount, status, syncStatus];
}

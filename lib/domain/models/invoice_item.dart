import 'package:equatable/equatable.dart';
import 'product.dart';

class InvoiceItem extends Equatable {
  final int? id;
  final int? invoiceId;
  final int productId;
  final String productName;
  final String? productBarcode;
  final int quantity;
  final double unitPrice;
  final double discountPercent;

  const InvoiceItem({
    this.id,
    this.invoiceId,
    required this.productId,
    required this.productName,
    this.productBarcode,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
  });

  double get subtotal {
    final gross = unitPrice * quantity;
    return gross - (gross * discountPercent / 100);
  }

  double get discountAmount => unitPrice * quantity * discountPercent / 100;

  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    int? productId,
    String? productName,
    String? productBarcode,
    int? quantity,
    double? unitPrice,
    double? discountPercent,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productBarcode: productBarcode ?? this.productBarcode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }

  factory InvoiceItem.fromProduct(Product product, {int quantity = 1}) {
    return InvoiceItem(
      productId: product.id,
      productName: product.name,
      productBarcode: product.barcode,
      quantity: quantity,
      unitPrice: product.sellPrice,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoice_id': invoiceId,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'unit_price': unitPrice,
    'discount_percent': discountPercent,
    'subtotal': subtotal,
  };

  @override
  List<Object?> get props => [productId, quantity, unitPrice, discountPercent];
}

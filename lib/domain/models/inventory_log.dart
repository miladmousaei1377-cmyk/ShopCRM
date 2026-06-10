import 'package:equatable/equatable.dart';

enum InventoryLogType { stockIn, stockOut, adjust, sale, refund }

extension InventoryLogTypeLabel on InventoryLogType {
  String get label {
    switch (this) {
      case InventoryLogType.stockIn: return 'ورود کالا';
      case InventoryLogType.stockOut: return 'خروج کالا';
      case InventoryLogType.adjust: return 'تعدیل موجودی';
      case InventoryLogType.sale: return 'فروش';
      case InventoryLogType.refund: return 'مرجوعی';
    }
  }

  bool get isIncrease => this == InventoryLogType.stockIn || this == InventoryLogType.refund;
}

class InventoryLog extends Equatable {
  final int id;
  final int productId;
  final String? productName;
  final InventoryLogType type;
  final int quantity;
  final int previousStock;
  final int newStock;
  final String? reason;
  final int? invoiceId;
  final DateTime createdAt;

  const InventoryLog({
    required this.id,
    required this.productId,
    this.productName,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.reason,
    this.invoiceId,
    required this.createdAt,
  });

  int get change => newStock - previousStock;
  bool get isIncrease => change > 0;

  @override
  List<Object?> get props => [id, productId, type, quantity, createdAt];
}

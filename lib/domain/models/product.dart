import 'package:equatable/equatable.dart';

enum SyncStatus { synced, pending, conflict }

class Product extends Equatable {
  final int id;
  final int? serverId;
  final String? barcode;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final double purchasePrice;
  final double sellPrice;
  final int stockQuantity;
  final int minStockAlert;
  final String? imageUrl;
  final bool isActive;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  const Product({
    required this.id,
    this.serverId,
    this.barcode,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.purchasePrice,
    required this.sellPrice,
    required this.stockQuantity,
    this.minStockAlert = 5,
    this.imageUrl,
    this.isActive = true,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  bool get isLowStock => stockQuantity <= minStockAlert;
  double get profitMargin => sellPrice > 0 ? ((sellPrice - purchasePrice) / sellPrice) * 100 : 0;
  double get profit => sellPrice - purchasePrice;

  Product copyWith({
    int? id,
    int? serverId,
    String? barcode,
    String? name,
    int? categoryId,
    String? categoryName,
    double? purchasePrice,
    double? sellPrice,
    int? stockQuantity,
    int? minStockAlert,
    String? imageUrl,
    bool? isActive,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Product(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'server_id': serverId,
    'barcode': barcode,
    'name': name,
    'category_id': categoryId,
    'purchase_price': purchasePrice,
    'sell_price': sellPrice,
    'stock_quantity': stockQuantity,
    'min_stock_alert': minStockAlert,
    'image_url': imageUrl,
    'is_active': isActive,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as int,
    serverId: json['server_id'] as int?,
    barcode: json['barcode'] as String?,
    name: json['name'] as String,
    categoryId: json['category_id'] as int?,
    purchasePrice: (json['purchase_price'] as num).toDouble(),
    sellPrice: (json['sell_price'] as num).toDouble(),
    stockQuantity: json['stock_quantity'] as int,
    minStockAlert: json['min_stock_alert'] as int? ?? 5,
    imageUrl: json['image_url'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    updatedAt: DateTime.parse(json['updated_at'] as String),
    syncStatus: SyncStatus.synced,
  );

  @override
  List<Object?> get props => [id, barcode, name, sellPrice, stockQuantity, syncStatus];
}

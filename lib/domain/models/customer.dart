import 'package:equatable/equatable.dart';
import 'product.dart';

class Customer extends Equatable {
  final int id;
  final int? serverId;
  final String name;
  final String? phone;
  final String? address;
  final double creditLimit;
  final double totalDebt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  const Customer({
    required this.id,
    this.serverId,
    required this.name,
    this.phone,
    this.address,
    this.creditLimit = 0,
    this.totalDebt = 0,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  bool get hasDebt => totalDebt > 0;
  bool get isOverCredit => totalDebt > creditLimit && creditLimit > 0;

  Customer copyWith({
    int? id,
    int? serverId,
    String? name,
    String? phone,
    String? address,
    double? creditLimit,
    double? totalDebt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Customer(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      creditLimit: creditLimit ?? this.creditLimit,
      totalDebt: totalDebt ?? this.totalDebt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'server_id': serverId,
    'name': name,
    'phone': phone,
    'address': address,
    'credit_limit': creditLimit,
    'total_debt': totalDebt,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as int,
    serverId: json['server_id'] as int?,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
    totalDebt: (json['total_debt'] as num?)?.toDouble() ?? 0,
    updatedAt: DateTime.parse(json['updated_at'] as String),
    syncStatus: SyncStatus.synced,
  );

  @override
  List<Object?> get props => [id, name, phone, totalDebt, syncStatus];
}

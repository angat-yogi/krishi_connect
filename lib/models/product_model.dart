import 'package:cloud_firestore/cloud_firestore.dart';

enum InventoryStatus { inStock, pending, sold }

extension InventoryStatusX on InventoryStatus {
  String get key => switch (this) {
        InventoryStatus.inStock => 'in_stock',
        InventoryStatus.pending => 'pending',
        InventoryStatus.sold => 'sold',
      };

  String get label => switch (this) {
        InventoryStatus.inStock => 'In Stock',
        InventoryStatus.pending => 'Pending',
        InventoryStatus.sold => 'Sold',
      };

  static InventoryStatus fromKey(String? key) {
    switch (key) {
      case 'pending':
        return InventoryStatus.pending;
      case 'sold':
        return InventoryStatus.sold;
      case 'in_stock':
      default:
        return InventoryStatus.inStock;
    }
  }
}

class Product {
  const Product({
    required this.id,
    required this.farmerId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.status,
    this.unit,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String farmerId;
  final String name;
  final int quantity;
  final double price;
  final InventoryStatus status;
  final String? unit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'farmerId': farmerId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'status': status.key,
      'unit': unit,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Product.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return Product(
      id: doc.id,
      farmerId: data['farmerId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      status: InventoryStatusX.fromKey(data['status'] as String?),
      unit: data['unit'] as String?,
      createdAt: _dateTimeFrom(data['createdAt']),
      updatedAt: _dateTimeFrom(data['updatedAt']),
    );
  }

  Product copyWith({
    String? farmerId,
    String? name,
    int? quantity,
    double? price,
    InventoryStatus? status,
    String? unit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id,
      farmerId: farmerId ?? this.farmerId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      status: status ?? this.status,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _dateTimeFrom(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

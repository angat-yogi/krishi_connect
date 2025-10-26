import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { requested, accepted, completed, cancelled }

extension OrderStatusX on OrderStatus {
  String get key => switch (this) {
        OrderStatus.requested => 'requested',
        OrderStatus.accepted => 'accepted',
        OrderStatus.completed => 'completed',
        OrderStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        OrderStatus.requested => 'Requested',
        OrderStatus.accepted => 'Accepted',
        OrderStatus.completed => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
      };

  static OrderStatus fromKey(String? key) {
    switch (key) {
      case 'accepted':
        return OrderStatus.accepted;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'requested':
      default:
        return OrderStatus.requested;
    }
  }
}

class Order {
  const Order({
    required this.id,
    required this.productId,
    required this.farmerId,
    required this.shopkeeperId,
    required this.quantity,
    required this.totalPrice,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String productId;
  final String farmerId;
  final String shopkeeperId;
  final int quantity;
  final double totalPrice;
  final OrderStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'farmerId': farmerId,
      'shopkeeperId': shopkeeperId,
      'quantity': quantity,
      'status': status.key,
      'totalPrice': totalPrice,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Order.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return Order(
      id: doc.id,
      productId: data['productId'] as String? ?? '',
      farmerId: data['farmerId'] as String? ?? '',
      shopkeeperId: data['shopkeeperId'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0,
      status: OrderStatusX.fromKey(data['status'] as String?),
      createdAt: _dateTimeFrom(data['createdAt']),
      updatedAt: _dateTimeFrom(data['updatedAt']),
    );
  }

  Order copyWith({
    String? productId,
    String? farmerId,
    String? shopkeeperId,
    int? quantity,
    double? totalPrice,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id,
      productId: productId ?? this.productId,
      farmerId: farmerId ?? this.farmerId,
      shopkeeperId: shopkeeperId ?? this.shopkeeperId,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
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

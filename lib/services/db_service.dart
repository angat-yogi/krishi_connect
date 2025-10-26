import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/order_model.dart';
import '../models/product_model.dart';

class DatabaseService {
  DatabaseService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('products');

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('orders');

  Stream<List<Product>> listenFarmerProducts(String farmerId) {
    return _productsRef
        .where('farmerId', isEqualTo: farmerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<Product>> listenAvailableProducts() {
    return _productsRef
        .where('status', isEqualTo: InventoryStatus.inStock.key)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList(),
        );
  }

  Future<String> createProduct({
    required String farmerId,
    required String name,
    required int quantity,
    required double price,
    InventoryStatus status = InventoryStatus.inStock,
    String? unit,
  }) async {
    final docRef = await _productsRef.add({
      'farmerId': farmerId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'status': status.key,
      'unit': unit,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateProduct({
    required String productId,
    String? name,
    int? quantity,
    double? price,
    InventoryStatus? status,
    String? unit,
  }) {
    return _productsRef.doc(productId).update({
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (price != null) 'price': price,
      if (status != null) 'status': status.key,
      if (unit != null) 'unit': unit,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String productId) {
    return _productsRef.doc(productId).delete();
  }

  Stream<List<Order>> listenOrdersForFarmer(String farmerId) {
    return _ordersRef
        .where('farmerId', isEqualTo: farmerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<Order>> listenOrdersForShopkeeper(String shopkeeperId) {
    return _ordersRef
        .where('shopkeeperId', isEqualTo: shopkeeperId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList(),
        );
  }

  Future<String> placeOrder({
    required Product product,
    required String shopkeeperId,
    required int quantity,
  }) async {
    final docRef = await _ordersRef.add({
      'productId': product.id,
      'farmerId': product.farmerId,
      'shopkeeperId': shopkeeperId,
      'quantity': quantity,
      'status': OrderStatus.requested.key,
      'totalPrice': product.price * quantity,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  }) {
    return _ordersRef.doc(orderId).update({
      'status': status.key,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

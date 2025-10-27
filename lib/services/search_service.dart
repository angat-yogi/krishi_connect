import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/feed_post.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/search_result.dart';
import '../models/user_model.dart';

class SearchService {
  SearchService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<SearchResultItem>> search(
    String query, {
    required UserProfile currentUser,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final qLower = trimmed.toLowerCase();
    final blocked = currentUser.blockedUsers.toSet();

    final results = <SearchResultItem>[];

    final usersSnapshot =
        await _firestore.collection('users').limit(40).get();
    for (final doc in usersSnapshot.docs) {
      final profile = UserProfile.fromMap(doc.id, doc.data());
      if (profile.uid == currentUser.uid) continue;
      if (blocked.contains(profile.uid)) continue;
      final label = profileDisplayLabel(profile).toLowerCase();
      final email = profile.email.toLowerCase();
      final location = (profile.location ?? '').toLowerCase();
      if (label.contains(qLower) ||
          email.contains(qLower) ||
          location.contains(qLower)) {
        results.add(SearchResultItem.user(profile));
      }
    }

    final productsSnapshot =
        await _firestore.collection('products').limit(40).get();
    for (final doc in productsSnapshot.docs) {
      final product = Product.fromFirestore(doc);
      if (blocked.contains(product.farmerId)) continue;
      if (product.name.toLowerCase().contains(qLower) ||
          (product.unit ?? '').toLowerCase().contains(qLower)) {
        results.add(SearchResultItem.product(product));
      }
    }

    final feedSnapshot =
        await _firestore.collection('feed_posts').limit(40).get();
    for (final doc in feedSnapshot.docs) {
      final post = FeedPost.fromFirestore(doc);
      if (blocked.contains(post.authorId)) continue;
      final text = '${post.title} ${post.description} ${post.location}'
          .toLowerCase();
      if (text.contains(qLower)) {
        results.add(SearchResultItem.feed(post));
      }
    }

    final ordersSnapshot = await _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();

    for (final doc in ordersSnapshot.docs) {
      final order = Order.fromFirestore(doc);
      if (blocked.contains(order.farmerId) ||
          blocked.contains(order.shopkeeperId)) {
        continue;
      }
      final idMatch = order.id.toLowerCase().contains(qLower);
      final statusMatch = order.status.label.toLowerCase().contains(qLower);

      Product? product;
      var matches = idMatch || statusMatch;

      if (!matches) {
        if (!blocked.contains(order.farmerId) &&
            !blocked.contains(order.shopkeeperId)) {
          final productDoc = await _firestore
              .collection('products')
              .doc(order.productId)
              .get();
          if (productDoc.exists) {
            product = Product.fromFirestore(productDoc);
            if (product.name.toLowerCase().contains(qLower)) {
              matches = true;
            }
          }
        }
      } else {
        if (!blocked.contains(order.farmerId) &&
            !blocked.contains(order.shopkeeperId)) {
          final productDoc = await _firestore
              .collection('products')
              .doc(order.productId)
              .get();
          if (productDoc.exists) {
            product = Product.fromFirestore(productDoc);
          }
        }
      }

      if (matches) {
        results.add(SearchResultItem.order(order: order, product: product));
      }
    }

    if (results.length > 40) {
      return results.sublist(0, 40);
    }
    return results;
  }
}

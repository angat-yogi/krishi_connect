import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/chat_models.dart';
import '../models/feed_post.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';

class MessagingException implements Exception {
  MessagingException(this.message);

  final String message;

  @override
  String toString() => 'MessagingException: $message';
}

class DatabaseService {
  DatabaseService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('products');

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('orders');

  CollectionReference<Map<String, dynamic>> get _feedPostsRef =>
      _firestore.collection('feed_posts');

  CollectionReference<Map<String, dynamic>> _feedCommentsRef(String postId) =>
      _feedPostsRef.doc(postId).collection('comments');

  CollectionReference<Map<String, dynamic>> get _threadsRef =>
      _firestore.collection('threads');

  CollectionReference<Map<String, dynamic>> _threadMessagesRef(
          String threadId) =>
      _threadsRef.doc(threadId).collection('messages');

  Stream<List<Product>> listenFarmerProducts(String farmerId) {
    return _productsRef
        .where('farmerId', isEqualTo: farmerId)
        .snapshots()
        .map((snapshot) {
      final products =
          snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
      products.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return products;
    });
  }

  Stream<List<Product>> listenAvailableProducts() {
    return _productsRef
        .where('status', isEqualTo: InventoryStatus.inStock.key)
        .snapshots()
        .map((snapshot) {
      final products =
          snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
      products.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return products;
    });
  }

  Future<String> createProduct({
    required String farmerId,
    required String name,
    required int quantity,
    required double price,
    InventoryStatus status = InventoryStatus.inStock,
    String? unit,
    String? imageUrl,
  }) async {
    final docRef = await _productsRef.add({
      'farmerId': farmerId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'status': status.key,
      'unit': unit,
      'imageUrl': imageUrl,
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
    String? imageUrl,
  }) {
    return _productsRef.doc(productId).update({
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (price != null) 'price': price,
      if (status != null) 'status': status.key,
      if (unit != null) 'unit': unit,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String productId) {
    return _productsRef.doc(productId).delete();
  }

  Stream<List<FeedPost>> listenFeedPosts() {
    return _feedPostsRef.snapshots().map((snapshot) {
      final posts = snapshot.docs.map(FeedPost.fromFirestore).toList();
      posts.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return posts;
    });
  }

  Stream<List<FeedComment>> listenFeedComments(String postId) {
    return _feedCommentsRef(postId).snapshots().map((snapshot) {
      final comments = snapshot.docs.map(FeedComment.fromFirestore).toList();
      comments.sort(
        (a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return comments;
    });
  }

  Future<void> addFeedComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String text,
  }) {
    return _feedCommentsRef(postId).add({
      'authorId': authorId,
      'authorName': authorName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createFeedPost({
    required String authorId,
    required String authorName,
    required String title,
    required String description,
    required String location,
  }) {
    return _feedPostsRef.add({
      'authorId': authorId,
      'authorName': authorName,
      'title': title,
      'description': description,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<FeedPost>> listenFeedPostsByAuthor(String uid) {
    return _feedPostsRef.where('authorId', isEqualTo: uid).snapshots().map(
      (snapshot) {
        final posts = snapshot.docs.map(FeedPost.fromFirestore).toList();
        posts.sort(
          (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
        );
        return posts;
      },
    );
  }

  Future<void> deleteFeedPost(String postId) {
    return _feedPostsRef.doc(postId).delete();
  }

  Stream<List<Order>> listenOrdersForFarmer(String farmerId) {
    return _ordersRef
        .where('farmerId', isEqualTo: farmerId)
        .snapshots()
        .map((snapshot) {
      final orders =
          snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
      orders.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return orders;
    });
  }

  Stream<List<Order>> listenOrdersForShopkeeper(String shopkeeperId) {
    return _ordersRef
        .where('shopkeeperId', isEqualTo: shopkeeperId)
        .snapshots()
        .map((snapshot) {
      final orders =
          snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
      orders.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return orders;
    });
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

  Stream<List<ChatThread>> listenThreads(String uid) {
    return _threadsRef
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final threads = snapshot.docs.map(ChatThread.fromFirestore).toList();
      threads.sort(
        (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return threads;
    });
  }

  Stream<List<ChatMessage>> listenMessages(String threadId) {
    return _threadMessagesRef(threadId).snapshots().map((snapshot) {
      final messages = snapshot.docs.map(ChatMessage.fromFirestore).toList();
      messages.sort(
        (a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return messages;
    });
  }

  Future<String> createOrGetThread({
    required String currentUid,
    required String otherUid,
    required Map<String, String> participantNames,
  }) async {
    final threadId = _threadId(currentUid, otherUid);
    final docRef = _threadsRef.doc(threadId);
    final currentProfile = await _fetchUserProfile(currentUid);
    final otherProfile = await _fetchUserProfile(otherUid);

    if (currentProfile == null || otherProfile == null) {
      throw MessagingException('Unable to load participants.');
    }

    if (currentProfile.blockedUsers.contains(otherUid) ||
        otherProfile.blockedUsers.contains(currentUid)) {
      throw MessagingException(
        'Messaging is blocked between these accounts.',
      );
    }

    final isMutualFollow = currentProfile.following.contains(otherUid) &&
        otherProfile.following.contains(currentUid);

    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'participants': [currentUid, otherUid],
        'participantNames': participantNames,
        'lastMessage': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'pendingParticipants': isMutualFollow ? <String>[] : <String>[otherUid],
        'blockedBy': const <String>[],
      });
    } else {
      final updates = <String, dynamic>{
        'participantNames': participantNames,
      };
      if (isMutualFollow) {
        updates['pendingParticipants'] =
            FieldValue.arrayRemove([currentUid, otherUid]);
      }
      await docRef.set(updates, SetOptions(merge: true));
    }
    return threadId;
  }

  Future<void> sendMessage({
    required String threadId,
    required String senderId,
    required String text,
  }) async {
    final threadSnapshot = await _threadsRef.doc(threadId).get();
    if (!threadSnapshot.exists) {
      throw MessagingException('Conversation not found.');
    }

    final thread = ChatThread.fromFirestore(threadSnapshot);

    if (thread.blockedBy.isNotEmpty) {
      throw MessagingException('Conversation has been blocked.');
    }

    if (thread.isPendingFor(senderId)) {
      throw MessagingException(
        'Approve the conversation before sending a message.',
      );
    }

    final otherId = thread.otherParticipant(senderId);
    final senderProfile = await _fetchUserProfile(senderId);
    final otherProfile = await _fetchUserProfile(otherId);

    if (senderProfile == null || otherProfile == null) {
      throw MessagingException('Unable to send message right now.');
    }

    if (senderProfile.blockedUsers.contains(otherId) ||
        otherProfile.blockedUsers.contains(senderId)) {
      throw MessagingException(
        'Messaging is blocked between these accounts.',
      );
    }

    final messagesRef = _threadMessagesRef(threadId);
    await messagesRef.add({
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _threadsRef.doc(threadId).update({
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _threadId(String a, String b) {
    final sorted = [a, b]..sort();
    return sorted.join('_');
  }

  Stream<UserProfile?> listenUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(uid, doc.data());
    });
  }

  Stream<List<UserProfile>> listenUsersByRole(UserRole role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role.key)
        .snapshots()
        .map((snapshot) {
      final profiles = snapshot.docs
          .map((doc) => UserProfile.fromMap(doc.id, doc.data()))
          .toList();
      profiles.sort((a, b) {
        String label(UserProfile profile) {
          final display = profile.displayName;
          if (display != null && display.trim().isNotEmpty) {
            return display.trim().toLowerCase();
          }
          return profile.email.toLowerCase();
        }

        return label(a).compareTo(label(b));
      });
      return profiles;
    });
  }

  Future<void> approveThread({
    required String threadId,
    required String approverId,
  }) {
    return _threadsRef.doc(threadId).set(
      {
        'pendingParticipants': FieldValue.arrayRemove([approverId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> markThreadBlocked({
    required String threadId,
    required String blockerId,
  }) async {
    final docRef = _threadsRef.doc(threadId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;
    await docRef.set(
      {
        'blockedBy': FieldValue.arrayUnion([blockerId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> markThreadUnblocked({
    required String threadId,
    required String blockerId,
  }) async {
    final docRef = _threadsRef.doc(threadId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;
    await docRef.set(
      {
        'blockedBy': FieldValue.arrayRemove([blockerId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<UserProfile?> _fetchUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return UserProfile.fromMap(uid, data);
  }

  Stream<ChatThread?> listenThread(String threadId) {
    return _threadsRef.doc(threadId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return ChatThread.fromFirestore(snapshot);
    });
  }
}

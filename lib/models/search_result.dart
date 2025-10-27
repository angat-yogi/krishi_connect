import '../models/feed_post.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';

enum SearchResultType {
  user,
  product,
  order,
  feedPost,
}

class SearchResultItem {
  const SearchResultItem._({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.payload,
  });

  final SearchResultType type;
  final String title;
  final String subtitle;
  final Object payload;

  factory SearchResultItem.user(UserProfile profile) {
    return SearchResultItem._(
      type: SearchResultType.user,
      title: profileDisplayLabel(profile),
      subtitle: profile.role?.label ?? 'KrishiConnect user',
      payload: profile,
    );
  }

  factory SearchResultItem.product(Product product) {
    return SearchResultItem._(
      type: SearchResultType.product,
      title: product.name,
      subtitle:
          '${product.quantity} ${product.unit ?? ''} • NPR ${product.price.toStringAsFixed(2)}',
      payload: product,
    );
  }

  factory SearchResultItem.order({
    required Order order,
    required Product? product,
  }) {
    final description = [
      if (product != null) product.name,
      'Status: ${order.status.label}',
      'Total: NPR ${order.totalPrice.toStringAsFixed(2)}',
    ].where((value) => value != null && value.isNotEmpty).join(' • ');

    return SearchResultItem._(
      type: SearchResultType.order,
      title: 'Order ${order.id.toUpperCase()}',
      subtitle: description,
      payload: OrderSearchPayload(order: order, product: product),
    );
  }

  factory SearchResultItem.feed(FeedPost post) {
    return SearchResultItem._(
      type: SearchResultType.feedPost,
      title: post.title,
      subtitle: '${post.authorName} • ${post.location}',
      payload: post,
    );
  }

  T payloadAs<T>() => payload as T;
}

class OrderSearchPayload {
  const OrderSearchPayload({
    required this.order,
    required this.product,
  });

  final Order order;
  final Product? product;
}

import 'package:flutter/material.dart';

import '../../models/feed_post.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/search_result.dart';
import '../../models/user_model.dart';
import '../../pages/messages/chat_page.dart';
import '../../pages/profile/user_profile_page.dart';
import '../../services/db_service.dart';
import '../../services/analytics_service.dart';

Future<void> handleSearchSelection(
  BuildContext context, {
  required SearchResultItem result,
  required DatabaseService databaseService,
  required UserProfile currentUser,
  required AnalyticsService analyticsService,
  required EngagementType engagementType,
}) async {
  switch (result.type) {
    case SearchResultType.user:
      final profile = result.payloadAs<UserProfile>();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfilePage(uid: profile.uid),
        ),
      );
      await analyticsService.logEngagement(
        userId: currentUser.uid,
        type: engagementType,
        targetType: EngagementTargetType.user,
        targetId: profile.uid,
        metadata: {
          'displayName': profileDisplayLabel(profile),
          'role': profile.role?.label,
        },
      );
      break;
    case SearchResultType.product:
      final product = result.payloadAs<Product>();
      await showModalBottomSheet(
        context: context,
        builder: (sheetContext) => _ProductQuickView(product: product),
      );
      await analyticsService.logEngagement(
        userId: currentUser.uid,
        type: engagementType,
        targetType: EngagementTargetType.product,
        targetId: product.id,
        metadata: {
          'name': product.name,
          'farmerId': product.farmerId,
        },
      );
      break;
    case SearchResultType.order:
      final payload = result.payloadAs<OrderSearchPayload>();
      await showModalBottomSheet(
        context: context,
        builder: (sheetContext) =>
            _OrderQuickView(order: payload.order, product: payload.product),
      );
      await analyticsService.logEngagement(
        userId: currentUser.uid,
        type: engagementType,
        targetType: EngagementTargetType.order,
        targetId: payload.order.id,
        metadata: {
          'status': payload.order.status.key,
          'productId': payload.order.productId,
        },
      );
      break;
    case SearchResultType.feedPost:
      final post = result.payloadAs<FeedPost>();
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => _FeedPostQuickView(
          post: post,
          databaseService: databaseService,
          currentUser: currentUser,
        ),
      );
      await analyticsService.logEngagement(
        userId: currentUser.uid,
        type: engagementType,
        targetType: EngagementTargetType.feedPost,
        targetId: post.id,
        metadata: {
          'authorId': post.authorId,
          'locationKey': post.location.toLowerCase(),
        },
      );
      break;
  }
}

class _ProductQuickView extends StatelessWidget {
  const _ProductQuickView({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Quantity: ${product.quantity} ${product.unit ?? ''}',
            ),
            Text('Price: NPR ${product.price.toStringAsFixed(2)}'),
            Text('Status: ${product.status.label}'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderQuickView extends StatelessWidget {
  const _OrderQuickView({required this.order, this.product});

  final Order order;
  final Product? product;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ${order.id.toUpperCase()}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (product != null) ...[
              Text('Product: ${product!.name}'),
              Text(
                'Quantity: ${order.quantity} ${product!.unit ?? ''}',
              ),
            ] else
              Text('Product ID: ${order.productId}'),
            Text('Total: NPR ${order.totalPrice.toStringAsFixed(2)}'),
            Text('Status: ${order.status.label}'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedPostQuickView extends StatelessWidget {
  const _FeedPostQuickView({
    required this.post,
    required this.databaseService,
    required this.currentUser,
  });

  final FeedPost post;
  final DatabaseService databaseService;
  final UserProfile currentUser;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('${post.authorName} • ${post.location}'),
            const SizedBox(height: 16),
            Text(
              post.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfilePage(uid: post.authorId),
                      ),
                    );
                  },
                  child: const Text('View author'),
                ),
                FilledButton.icon(
                  onPressed: currentUser.uid == post.authorId
                      ? null
                      : () async {
                          try {
                            final threadId =
                                await databaseService.createOrGetThread(
                              currentUid: currentUser.uid,
                              otherUid: post.authorId,
                              participantNames: {
                                currentUser.uid:
                                    profileDisplayLabel(currentUser),
                                post.authorId: post.authorName,
                              },
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    threadId: threadId,
                                    currentUserId: currentUser.uid,
                                    otherUserId: post.authorId,
                                    otherDisplayName: post.authorName,
                                  ),
                                ),
                              );
                            }
                          } on MessagingException catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message author'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

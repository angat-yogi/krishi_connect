import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../models/feed_post.dart';
import '../../models/chat_models.dart';
import '../../services/db_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/profile_drawer.dart';
import '../messages/chat_page.dart';

class FarmerDashboardPage extends StatefulWidget {
  const FarmerDashboardPage({super.key});

  @override
  State<FarmerDashboardPage> createState() => _FarmerDashboardPageState();
}

class _FarmerDashboardPageState extends State<FarmerDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfile?>();

    if (profile == null) {
      return const Scaffold(
          body: LoadingView(message: 'Loading your profile...'));
    }

    if (profile.role != UserRole.farmer) {
      return Scaffold(
        appBar: AppBar(title: const Text('Farmer Dashboard')),
        body: const Center(
            child: Text('Switch to a farmer account to view this page.')),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: const ProfileDrawer(),
        appBar: AppBar(
          titleSpacing: 0,
          title: const _AppLogo(),
          actions: [
            TextButton.icon(
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(
                profileHeaderLabel(profile),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.dynamic_feed_outlined), text: 'Feed'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventory'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Orders'),
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Messages'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FeedTab(profile: profile),
            _InventoryTab(farmerId: profile.uid),
            _OrdersTab(farmerId: profile.uid),
            _MessagesTab(profile: profile),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showProductForm(context, profile),
          icon: const Icon(Icons.add),
          label: const Text('Add Inventory'),
        ),
      ),
    );
  }

  Future<void> _showProductForm(
      BuildContext context, UserProfile profile) async {
    final db = context.read<DatabaseService>();
    final storage = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final unitController = TextEditingController(text: 'kg');
    final formKey = GlobalKey<FormState>();
    final picker = ImagePicker();
    File? imageFile;
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24.w,
            right: 24.w,
            top: 24.h,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24.h,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickImage() async {
                final result = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (result != null) {
                  setModalState(() {
                    imageFile = File(result.path);
                  });
                }
              }

              Future<void> submit() async {
                if (!formKey.currentState!.validate()) return;
                setModalState(() => isSubmitting = true);
                try {
                  String? imageUrl;
                  if (imageFile != null) {
                    imageUrl = await storage.uploadProductImage(
                      file: imageFile!,
                      farmerId: profile.uid,
                    );
                  }

                  await db.createProduct(
                    farmerId: profile.uid,
                    name: nameController.text.trim(),
                    quantity: int.parse(quantityController.text),
                    price: double.parse(priceController.text),
                    unit: unitController.text.trim().isEmpty
                        ? null
                        : unitController.text.trim(),
                    imageUrl: imageUrl,
                  );
                  if (mounted) Navigator.of(sheetContext).pop();
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Unable to save product. Try again.'),
                    ),
                  );
                } finally {
                  setModalState(() => isSubmitting = false);
                }
              }

              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: isSubmitting ? null : pickImage,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 120,
                            width: 120,
                            color: Colors.grey[200],
                            child: imageFile != null
                                ? Image.file(imageFile!, fit: BoxFit.cover)
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.add_a_photo_outlined,
                                          size: 32),
                                      SizedBox(height: 8),
                                      Text('Add photo'),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Add new inventory',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 20.h),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Produce name',
                        prefixIcon: Icon(Icons.spa_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.scale),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final parsed = int.tryParse(value);
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid quantity';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit (e.g. kg, sack)',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price per unit (NPR)',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final parsed = double.tryParse(value);
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid price';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24.h),
                    FilledButton(
                      onPressed: isSubmitting ? null : submit,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _InventoryTab extends StatelessWidget {
  const _InventoryTab({required this.farmerId});

  final String farmerId;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    return StreamBuilder<List<Product>>(
      stream: db.listenFarmerProducts(farmerId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final products = snapshot.data ?? [];
        final tabs = [
          {
            'label': 'All',
            'items': products,
          },
          {
            'label': InventoryStatus.inStock.label,
            'items': products
                .where((p) => p.status == InventoryStatus.inStock)
                .toList(),
          },
          {
            'label': InventoryStatus.pending.label,
            'items': products
                .where((p) => p.status == InventoryStatus.pending)
                .toList(),
          },
          {
            'label': InventoryStatus.sold.label,
            'items': products
                .where((p) => p.status == InventoryStatus.sold)
                .toList(),
          },
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Column(
            children: [
              TabBar(
                isScrollable: true,
                labelColor: Theme.of(context).colorScheme.primary,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: [
                  for (final tab in tabs) Tab(text: tab['label'] as String),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final tab in tabs)
                      (tab['items'] as List<Product>).isEmpty
                          ? const _EmptyState(
                              icon: Icons.inventory_2_outlined,
                              message:
                                  'No inventory yet.\nTap "Add Inventory" to get started.',
                            )
                          : ListView.separated(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 24.h,
                              ),
                              itemCount: (tab['items'] as List<Product>).length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: 12.h),
                              itemBuilder: (context, index) {
                                final product =
                                    (tab['items'] as List<Product>)[index];
                                return Card(
                                  child: ListTile(
                                    leading: _ProductThumbnail(
                                      imageUrl: product.imageUrl,
                                    ),
                                    title: Text(product.name),
                                    subtitle: Text(
                                      '${product.quantity} ${product.unit ?? ''} • NPR ${product.price.toStringAsFixed(2)}',
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'in_stock':
                                            context
                                                .read<DatabaseService>()
                                                .updateProduct(
                                                  productId: product.id,
                                                  status:
                                                      InventoryStatus.inStock,
                                                );
                                            break;
                                          case 'pending':
                                            context
                                                .read<DatabaseService>()
                                                .updateProduct(
                                                  productId: product.id,
                                                  status:
                                                      InventoryStatus.pending,
                                                );
                                            break;
                                          case 'sold':
                                            context
                                                .read<DatabaseService>()
                                                .updateProduct(
                                                  productId: product.id,
                                                  status: InventoryStatus.sold,
                                                );
                                            break;
                                          case 'delete':
                                            context
                                                .read<DatabaseService>()
                                                .deleteProduct(product.id);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'in_stock',
                                          child: Text('Mark as In stock'),
                                        ),
                                        PopupMenuItem(
                                          value: 'pending',
                                          child: Text('Mark as Pending'),
                                        ),
                                        PopupMenuItem(
                                          value: 'sold',
                                          child: Text('Mark as Sold'),
                                        ),
                                        PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.farmerId});

  final String farmerId;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    return StreamBuilder<List<Order>>(
      stream: db.listenOrdersForFarmer(farmerId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const _EmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'No orders yet. Orders you receive will appear here.',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          itemCount: orders.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              child: ListTile(
                title: Text(
                  'Order • NPR ${order.totalPrice.toStringAsFixed(2)}',
                ),
                subtitle: Text(
                  'Qty: ${order.quantity}\nStatus: ${order.status.label}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<OrderStatus>(
                  onSelected: (status) {
                    context.read<DatabaseService>().updateOrderStatus(
                          orderId: order.id,
                          status: status,
                        );
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: OrderStatus.requested,
                      child: Text('Mark as Requested'),
                    ),
                    PopupMenuItem(
                      value: OrderStatus.accepted,
                      child: Text('Mark as Accepted'),
                    ),
                    PopupMenuItem(
                      value: OrderStatus.completed,
                      child: Text('Mark as Completed'),
                    ),
                    PopupMenuItem(
                      value: OrderStatus.cancelled,
                      child: Text('Mark as Cancelled'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    return StreamBuilder<List<FeedPost>>(
      stream: db.listenFeedPosts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return const _EmptyState(
            icon: Icons.dynamic_feed_outlined,
            message:
                'Market is quiet for now. Check back soon for new requests.',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          itemCount: posts.length,
          separatorBuilder: (_, __) => SizedBox(height: 16.h),
          itemBuilder: (context, index) {
            final post = posts[index];
            return _FeedPostCard(profile: profile, post: post);
          },
        );
      },
    );
  }
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    return StreamBuilder<List<ChatThread>>(
      stream: db.listenThreads(profile.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final threads = snapshot.data ?? [];
        if (threads.isEmpty) {
          return const _EmptyState(
            icon: Icons.chat_bubble_outline,
            message:
                'No conversations yet. Reply to a feed or message a seller to get started.',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          itemCount: threads.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final thread = threads[index];
            final otherId = thread.participants
                .firstWhere((id) => id != profile.uid, orElse: () => profile.uid);
            final otherName =
                thread.participantNames[otherId] ?? 'Conversation';

            return Card(
              child: ListTile(
                title: Text(otherName),
                subtitle: Text(thread.lastMessage ?? 'Tap to chat'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        threadId: thread.id,
                        currentUserId: profile.uid,
                        otherUserId: otherId,
                        otherDisplayName: otherName,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({required this.profile, required this.post});

  final UserProfile profile;
  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    final theme = Theme.of(context);
    final createdText = post.createdAt != null
        ? 'Posted ${timeAgo(post.createdAt!)}'
        : 'Posted recently';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      theme.colorScheme.primary.withOpacity(0.15),
                  child: const Icon(Icons.storefront, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text('${post.authorName} • ${post.location}',
                          style: theme.textTheme.bodySmall),
                      Text(createdText, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  onPressed: () => _promptComment(context, db),
                  icon: const Icon(Icons.mode_comment_outlined),
                  label: const Text('Comment'),
                ),
                TextButton.icon(
                  onPressed: () => _openChat(context, db),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message seller'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<FeedComment>>(
              stream: db.listenFeedComments(post.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox();
                }
                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return Text(
                    'No comments yet. Be the first to reach out!',
                    style: theme.textTheme.bodySmall,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Responses',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    ...comments.take(3).map(
                      (comment) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: '${comment.authorName}: ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: comment.text),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (comments.length > 3)
                      Text(
                        '+${comments.length - 3} more replies',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptComment(
    BuildContext context,
    DatabaseService db,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Respond to ${post.authorName}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Let them know you can help…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  await db.addFeedComment(
                    postId: post.id,
                    authorId: profile.uid,
                    authorName: profileDisplayLabel(profile),
                    text: text,
                  );
                  if (context.mounted) {
                    Navigator.of(sheetContext).pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Comment sent.')),
                    );
                  }
                },
                child: const Text('Send'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openChat(
    BuildContext context,
    DatabaseService db,
  ) async {
    final participantNames = <String, String>{
      profile.uid: profileDisplayLabel(profile),
      post.authorId: post.authorName,
    };
    final threadId = await db.createOrGetThread(
      currentUid: profile.uid,
      otherUid: post.authorId,
      participantNames: participantNames,
    );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          threadId: threadId,
          currentUserId: profile.uid,
          otherUserId: post.authorId,
          otherDisplayName: post.authorName,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72.sp, color: Colors.grey),
          SizedBox(height: 16.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'Something went wrong while loading data.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                '$error',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Coming\nSoon',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey[600]),
        ),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: 64,
            height: 64,
            child:
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.agriculture, color: Color(0xFF2E7D32)),
        ),
        const SizedBox(width: 8),
        Text(
          'KrishiConnect',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 1) {
    return '${diff.inDays}d ago';
  } else if (diff.inHours >= 1) {
    return '${diff.inHours}h ago';
  } else if (diff.inMinutes >= 1) {
    return '${diff.inMinutes}m ago';
  }
  return 'just now';
}

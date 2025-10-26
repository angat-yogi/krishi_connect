import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/db_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/profile_drawer.dart';

class ShopkeeperDashboardPage extends StatefulWidget {
  const ShopkeeperDashboardPage({super.key});

  @override
  State<ShopkeeperDashboardPage> createState() =>
      _ShopkeeperDashboardPageState();
}

class _ShopkeeperDashboardPageState extends State<ShopkeeperDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfile?>();

    if (profile == null) {
      return const Scaffold(
          body: LoadingView(message: 'Loading your profile...'));
    }

    if (profile.role != UserRole.shopkeeper) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shopkeeper Dashboard')),
        body: const Center(
            child: Text('Switch to a shopkeeper account to view this page.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: const ProfileDrawer(),
        appBar: AppBar(
          title: const Text('Shopkeeper Dashboard'),
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Browse'),
              Tab(text: 'My Orders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BrowseTab(shopkeeperId: profile.uid),
            _OrdersTab(shopkeeperId: profile.uid),
          ],
        ),
      ),
    );
  }
}

class _BrowseTab extends StatelessWidget {
  const _BrowseTab({required this.shopkeeperId});

  final String shopkeeperId;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    return StreamBuilder<List<Product>>(
      stream: db.listenAvailableProducts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return const _EmptyState(
            icon: Icons.search_off,
            message: 'No produce is available right now. Check back soon!',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          itemCount: products.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final product = products[index];
            return Card(
              child: ListTile(
                title: Text(product.name),
                subtitle: Text(
                  '${product.quantity} ${product.unit ?? ''} • NPR ${product.price.toStringAsFixed(2)}',
                ),
                trailing: FilledButton(
                  onPressed: () =>
                      _showOrderSheet(context, product, shopkeeperId),
                  child: const Text('Order'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showOrderSheet(
    BuildContext context,
    Product product,
    String shopkeeperId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final quantityController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
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
              Future<void> submit() async {
                if (!formKey.currentState!.validate()) return;
                setModalState(() => isSubmitting = true);
                try {
                  await sheetContext.read<DatabaseService>().placeOrder(
                        product: product,
                        shopkeeperId: shopkeeperId,
                        quantity: int.parse(quantityController.text),
                      );
                  Navigator.of(sheetContext).pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Order placed successfully!')),
                  );
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Could not place order. Please retry.'),
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
                    Text(
                      'Order ${product.name}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Available: ${product.quantity} ${product.unit ?? ''}\nPrice per unit: NPR ${product.price.toStringAsFixed(2)}',
                    ),
                    SizedBox(height: 24.h),
                    TextFormField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.confirmation_number),
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
                    SizedBox(height: 24.h),
                    FilledButton(
                      onPressed: isSubmitting ? null : submit,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Place order'),
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

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.shopkeeperId});

  final String shopkeeperId;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    return StreamBuilder<List<Order>>(
      stream: db.listenOrdersForShopkeeper(shopkeeperId),
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
            icon: Icons.local_shipping_outlined,
            message: 'Orders you place will appear here.',
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
                title: Text('Order ${_orderLabel(order.id)}'),
                subtitle: Text(
                  'Quantity: ${order.quantity}\nTotal: NPR ${order.totalPrice.toStringAsFixed(2)}\nStatus: ${order.status.label}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
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

String _orderLabel(String id) {
  if (id.isEmpty) return 'UNKNOWN';
  final length = id.length >= 6 ? 6 : id.length;
  return id.substring(0, length).toUpperCase();
}

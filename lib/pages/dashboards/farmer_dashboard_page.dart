import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/db_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/profile_drawer.dart';

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
      length: 2,
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: const ProfileDrawer(),
        appBar: AppBar(
          title: const Text('Farmer Dashboard'),
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
              Tab(text: 'Inventory'),
              Tab(text: 'Orders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _InventoryTab(farmerId: profile.uid),
            _OrdersTab(farmerId: profile.uid),
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
        if (products.isEmpty) {
          return const _EmptyState(
            icon: Icons.inventory_2_outlined,
            message: 'No inventory yet.\nTap "Add Inventory" to get started.',
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
                leading: _ProductThumbnail(imageUrl: product.imageUrl),
                title: Text(product.name),
                subtitle: Text(
                  '${product.quantity} ${product.unit ?? ''} • NPR ${product.price.toStringAsFixed(2)}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'in_stock':
                        context.read<DatabaseService>().updateProduct(
                              productId: product.id,
                              status: InventoryStatus.inStock,
                            );
                        break;
                      case 'pending':
                        context.read<DatabaseService>().updateProduct(
                              productId: product.id,
                              status: InventoryStatus.pending,
                            );
                        break;
                      case 'sold':
                        context.read<DatabaseService>().updateProduct(
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

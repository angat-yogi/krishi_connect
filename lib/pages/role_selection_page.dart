import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  bool _isUpdating = false;

  Future<void> _selectRole(UserRole role) async {
    setState(() => _isUpdating = true);
    try {
      await context.read<AuthService>().updateUserRole(role);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to update role. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Choose your role'),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome, ${widget.profile.displayName ?? widget.profile.email}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 12.h),
            Text(
              'How would you like to use KrishiConnect?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 32.h),
            _RoleCard(
              title: 'Farmer',
              description:
                  'List produce, manage inventory, and track orders from local shopkeepers.',
              icon: Icons.agriculture,
              onTap: _isUpdating ? null : () => _selectRole(UserRole.farmer),
            ),
            SizedBox(height: 24.h),
            _RoleCard(
              title: 'Shopkeeper',
              description:
                  'Browse local farmers, place orders, and monitor delivery status.',
              icon: Icons.storefront,
              onTap:
                  _isUpdating ? null : () => _selectRole(UserRole.shopkeeper),
            ),
            if (_isUpdating) ...[
              SizedBox(height: 32.h),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Ink(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Theme.of(context).colorScheme.primary),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 48.sp,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16.sp),
          ],
        ),
      ),
    );
  }
}

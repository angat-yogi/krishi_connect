import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../widgets/loading_view.dart';
import '../dashboards/farmer_dashboard_page.dart';
import '../dashboards/shopkeeper_dashboard_page.dart';
import '../role_selection_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final profile = context.watch<UserProfile?>();

    if (user == null) {
      return const LoginPage();
    }

    if (profile == null) {
      return const Scaffold(
        body: LoadingView(message: 'Loading your profile...'),
      );
    }

    if (profile.role == null) {
      return RoleSelectionPage(profile: profile);
    }

    return switch (profile.role) {
      UserRole.farmer => FarmerDashboardPage(profile: profile),
      UserRole.shopkeeper => ShopkeeperDashboardPage(profile: profile),
      null => const Scaffold(body: LoadingView()),
    };
  }
}

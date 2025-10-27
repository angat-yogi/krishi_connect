import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/db_service.dart';
import '../../widgets/loading_view.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Seller profile')),
      body: StreamBuilder<UserProfile?>(
        stream: db.listenUserProfile(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load profile.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('Profile not available.'));
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: profile.photoUrl != null &&
                                profile.photoUrl!.isNotEmpty
                            ? Image.network(profile.photoUrl!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.storefront,
                                  size: 40,
                                  color: Colors.green,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profileDisplayLabel(profile),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            profile.role?.label ?? 'Seller',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if ((profile.location ?? '').isNotEmpty)
                            Text(
                              profile.location!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          Text(
                            profile.email,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'This seller joined KrishiConnect to source fresh produce from local farmers. Reach out via the feed or start a conversation in Messages.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

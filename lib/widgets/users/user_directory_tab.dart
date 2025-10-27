import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/db_service.dart';
import '../loading_view.dart';
import '../../pages/messages/chat_page.dart';
import '../../pages/profile/user_profile_page.dart';

class UserDirectoryTab extends StatelessWidget {
  const UserDirectoryTab({
    super.key,
    required this.currentUser,
    required this.roleToShow,
    required this.emptyMessage,
    this.emptyIcon = Icons.people_alt_outlined,
  });

  final UserProfile currentUser;
  final UserRole roleToShow;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    return StreamBuilder<List<UserProfile>>(
      stream: db.listenUsersByRole(roleToShow),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _DirectoryMessage(
            icon: Icons.error_outline,
            message: 'Unable to load partners right now.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }

        final users = (snapshot.data ?? [])
            .where((profile) => profile.uid != currentUser.uid)
            .toList();

        if (users.isEmpty) {
          return _DirectoryMessage(icon: emptyIcon, message: emptyMessage);
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          itemCount: users.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final partner = users[index];
            return _DirectoryCard(
              currentUser: currentUser,
              partner: partner,
            );
          },
        );
      },
    );
  }
}

class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({
    required this.currentUser,
    required this.partner,
  });

  final UserProfile currentUser;
  final UserProfile partner;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DirectoryAvatar(photoUrl: partner.photoUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayLabel(partner),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        partner.role?.label ?? 'KrishiConnect user',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if ((partner.location ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                partner.location!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        partner.email,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfilePage(uid: partner.uid),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('View profile'),
                ),
                FilledButton.icon(
                  onPressed: () => _startConversation(context),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startConversation(BuildContext context) async {
    final db = context.read<DatabaseService>();
    final threadId = await db.createOrGetThread(
      currentUid: currentUser.uid,
      otherUid: partner.uid,
      participantNames: {
        currentUser.uid: _displayLabel(currentUser),
        partner.uid: _displayLabel(partner),
      },
    );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          threadId: threadId,
          currentUserId: currentUser.uid,
          otherUserId: partner.uid,
          otherDisplayName: _displayLabel(partner),
        ),
      ),
    );
  }
}

class _DirectoryAvatar extends StatelessWidget {
  const _DirectoryAvatar({this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 64,
        height: 64,
        color: Colors.grey[200],
        child: (photoUrl != null && photoUrl!.isNotEmpty)
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Icon(
      Icons.store_mall_directory_outlined,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

class _DirectoryMessage extends StatelessWidget {
  const _DirectoryMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

String _displayLabel(UserProfile profile) {
  final display = profile.displayName;
  if (display != null && display.trim().isNotEmpty) {
    return display.trim();
  }
  return profile.email;
}

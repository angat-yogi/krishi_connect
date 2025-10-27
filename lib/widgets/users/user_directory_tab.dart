import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../models/recommendation.dart';
import '../../models/user_model.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/recommendation_service.dart';
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

        final recommendationService = context.read<RecommendationService>();

        return FutureBuilder<List<UserRecommendation>>(
          future: recommendationService.recommendPartners(
            currentUser: currentUser,
            targetRole: roleToShow,
          ),
          builder: (context, recommendationSnapshot) {
            final recommended =
                recommendationSnapshot.data ?? const <UserRecommendation>[];
            final showRecommendations = recommended.isNotEmpty;

            if (users.isEmpty && !showRecommendations) {
              return _DirectoryMessage(icon: emptyIcon, message: emptyMessage);
            }

            return ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
              itemCount: users.length + (showRecommendations ? 1 : 0),
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                if (showRecommendations) {
                  if (index == 0) {
                    if (recommendationSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SizedBox(
                        height: 64,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return _RecommendedPartnersSection(
                      currentUser: currentUser,
                      recommendations: recommended,
                    );
                  }
                  final partner = users[index - 1];
                  return _DirectoryCard(
                    currentUser: currentUser,
                    partner: partner,
                  );
                }
                final partner = users[index];
                return _DirectoryCard(
                  currentUser: currentUser,
                  partner: partner,
                );
              },
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

  bool get _isFollowing => currentUser.following.contains(partner.uid);

  bool get _isBlocked => currentUser.blockedUsers.contains(partner.uid);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            if (_isBlocked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  label: const Text('Blocked'),
                  backgroundColor:
                      theme.colorScheme.errorContainer.withOpacity(0.6),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      _isBlocked ? null : () => _startConversation(context),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _viewProfile(context),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('View profile'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _toggleFollow(context, follow: !_isFollowing),
                  icon: Icon(_isFollowing ? Icons.check : Icons.add),
                  label: Text(_isFollowing ? 'Following' : 'Follow'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      _toggleBlock(context, unblock: _isBlocked),
                  icon: Icon(_isBlocked ? Icons.lock_open : Icons.block),
                  label: Text(_isBlocked ? 'Unblock' : 'Block'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startConversation(BuildContext context) async {
    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unblock this user before starting a conversation.'),
        ),
      );
      return;
    }
    final db = context.read<DatabaseService>();
    final messenger = ScaffoldMessenger.of(context);
    final analytics = context.read<AnalyticsService>();
    try {
      final threadId = await db.createOrGetThread(
        currentUid: currentUser.uid,
        otherUid: partner.uid,
        participantNames: {
          currentUser.uid: _displayLabel(currentUser),
          partner.uid: _displayLabel(partner),
        },
      );
      await analytics.logEngagement(
        userId: currentUser.uid,
        type: EngagementType.messageOpen,
        targetType: EngagementTargetType.user,
        targetId: partner.uid,
        metadata: {
          'displayName': _displayLabel(partner),
          'context': 'directory',
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
    } on MessagingException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to start conversation: $e')),
      );
    }
  }

  Future<void> _toggleFollow(
    BuildContext context, {
    required bool follow,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final auth = context.read<AuthService>();
      final analytics = context.read<AnalyticsService>();
      if (follow) {
        await auth.followUser(partner.uid);
        messenger.showSnackBar(
          SnackBar(content: Text('Following ${_displayLabel(partner)}.')),
        );
        await analytics.logEngagement(
          userId: currentUser.uid,
          type: EngagementType.follow,
          targetType: EngagementTargetType.user,
          targetId: partner.uid,
          metadata: {
            'displayName': _displayLabel(partner),
            'direction': 'follow',
          },
        );
      } else {
        await auth.unfollowUser(partner.uid);
        messenger.showSnackBar(
          SnackBar(content: Text('Unfollowed ${_displayLabel(partner)}.')),
        );
        await analytics.logEngagement(
          userId: currentUser.uid,
          type: EngagementType.follow,
          targetType: EngagementTargetType.user,
          targetId: partner.uid,
          metadata: {
            'displayName': _displayLabel(partner),
            'direction': 'unfollow',
          },
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to update follow status: $e')),
      );
    }
  }

  Future<void> _toggleBlock(
    BuildContext context, {
    required bool unblock,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final auth = context.read<AuthService>();
      final db = context.read<DatabaseService>();
      final analytics = context.read<AnalyticsService>();
      final threadId = ([currentUser.uid, partner.uid]..sort()).join('_');

      if (unblock) {
        await auth.unblockUser(partner.uid);
        await db.markThreadUnblocked(
          threadId: threadId,
          blockerId: currentUser.uid,
        );
        messenger.showSnackBar(
          SnackBar(content: Text('Unblocked ${_displayLabel(partner)}.')),
        );
        await analytics.logEngagement(
          userId: currentUser.uid,
          type: EngagementType.feedInteraction,
          targetType: EngagementTargetType.user,
          targetId: partner.uid,
          metadata: {
            'action': 'unblock',
          },
        );
      } else {
        await auth.blockUser(partner.uid);
        await db.markThreadBlocked(
          threadId: threadId,
          blockerId: currentUser.uid,
        );
        messenger.showSnackBar(
          SnackBar(content: Text('Blocked ${_displayLabel(partner)}.')),
        );
        await analytics.logEngagement(
          userId: currentUser.uid,
          type: EngagementType.feedInteraction,
          targetType: EngagementTargetType.user,
          targetId: partner.uid,
          metadata: {
            'action': 'block',
          },
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to update block status: $e')),
      );
    }
  }

  void _viewProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(uid: partner.uid),
      ),
    );
  }
}

class _RecommendedPartnersSection extends StatelessWidget {
  const _RecommendedPartnersSection({
    required this.currentUser,
    required this.recommendations,
  });

  final UserProfile currentUser;
  final List<UserRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested partners',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            separatorBuilder: (_, __) => SizedBox(width: 12.w),
            itemBuilder: (context, index) {
              final rec = recommendations[index];
              final profile = rec.profile;
              return _RecommendationChip(
                currentUser: currentUser,
                recommendation: rec,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendationChip extends StatelessWidget {
  const _RecommendationChip({
    required this.currentUser,
    required this.recommendation,
  });

  final UserProfile currentUser;
  final UserRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final profile = recommendation.profile;
    final theme = Theme.of(context);
    final reasons = recommendation.reasons;
    final displayReasons =
        reasons.isNotEmpty ? reasons.take(2).toList() : ['Active in your network'];
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserProfilePage(uid: profile.uid),
          ),
        );
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              profileDisplayLabel(profile),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    profile.location ?? 'Location not set',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Why suggested',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            for (final reason in displayReasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        reason,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserProfilePage(uid: profile.uid),
                    ),
                  );
                },
                child: const Text('View profile'),
              ),
            ),
          ],
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

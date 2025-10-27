import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../models/chat_models.dart';
import '../../models/feed_post.dart';
import '../../models/recommendation.dart';
import '../../models/user_model.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/recommendation_service.dart';
import '../../widgets/loading_view.dart';
import '../../pages/feed/create_feed_post_page.dart';
import '../../pages/messages/chat_page.dart';
import '../../pages/profile/user_profile_page.dart';

class FeedTabView extends StatelessWidget {
  const FeedTabView({
    super.key,
    required this.profile,
    this.ownPostsOnly = false,
  });

  final UserProfile profile;
  final bool ownPostsOnly;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    final stream = ownPostsOnly
        ? db.listenFeedPostsByAuthor(profile.uid)
        : db.listenFeedPosts();

    return StreamBuilder<List<FeedPost>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ErrorNotice(
            icon: Icons.dynamic_feed_outlined,
            message: 'Failed to load market feed.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final posts = snapshot.data ?? [];
        final showRecommendations = !ownPostsOnly;

        if (posts.isEmpty && !ownPostsOnly) {
          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
            children: const [
              _FeedRecommendationSection.emptyPlaceholder(),
              SizedBox(height: 16),
              _ErrorNotice(
                icon: Icons.dynamic_feed_outlined,
                message:
                    'Market is quiet for now. Check back soon for new requests.',
              ),
            ],
          );
        }

        final list = List<FeedPost>.from(posts);
        final baseItems = <Widget>[];
        if (ownPostsOnly) {
          baseItems.add(_CreatePostCard(profile: profile));
        }
        baseItems.addAll(
          list.map(
            (post) => FeedPostCard(profile: profile, post: post),
          ),
        );

        final itemCount = baseItems.length + (showRecommendations ? 1 : 0);

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          itemCount: itemCount,
          separatorBuilder: (_, __) => SizedBox(height: 16.h),
          itemBuilder: (context, index) {
            if (showRecommendations) {
              if (index == 0) {
                return _FeedRecommendationSection(profile: profile);
              }
              return baseItems[index - 1];
            }
            return baseItems[index];
          },
        );
      },
    );
  }
}

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.profile,
    required this.post,
    this.highlightReasons,
  });

  final UserProfile profile;
  final FeedPost post;
  final List<String>? highlightReasons;

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    final analytics = context.read<AnalyticsService>();
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
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserProfilePage(uid: post.authorId),
                    ),
                  ).then((_) async {
                    await analytics.logEngagement(
                      userId: profile.uid,
                      type: EngagementType.profileView,
                      targetType: EngagementTargetType.user,
                      targetId: post.authorId,
                      metadata: {
                        'displayName': post.authorName,
                        'context': 'feed_card',
                      },
                    );
                  }),
                  child: const Text('View profile'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (highlightReasons?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: highlightReasons!
                      .map(
                        (reason) => Chip(
                          label: Text(reason),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ),
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
    final analytics = context.read<AnalyticsService>();
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
                  await analytics.logEngagement(
                    userId: profile.uid,
                    type: EngagementType.feedInteraction,
                    targetType: EngagementTargetType.feedPost,
                    targetId: post.id,
                    metadata: {
                      'authorId': post.authorId,
                      'locationKey': post.location.toLowerCase(),
                      'interaction': 'comment',
                    },
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
    if (profile.uid == post.authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your own request.')), 
      );
      return;
    }

    final participantNames = <String, String>{
      profile.uid: profileDisplayLabel(profile),
      post.authorId: post.authorName,
    };
    final messenger = ScaffoldMessenger.of(context);
    try {
    final threadId = await db.createOrGetThread(
      currentUid: profile.uid,
      otherUid: post.authorId,
      participantNames: participantNames,
    );
    await context.read<AnalyticsService>().logEngagement(
          userId: profile.uid,
          type: EngagementType.feedInteraction,
          targetType: EngagementTargetType.feedPost,
          targetId: post.id,
          metadata: {
            'authorId': post.authorId,
            'locationKey': post.location.toLowerCase(),
            'interaction': 'message',
          },
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
    } on MessagingException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to start chat: $e')),
      );
    }
  }
}

class MessagesTabView extends StatelessWidget {
  const MessagesTabView({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    return StreamBuilder<List<ChatThread>>(
      stream: db.listenThreads(profile.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ErrorNotice(
            icon: Icons.chat_bubble_outline,
            message: 'Unable to load conversations.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final threads = snapshot.data ?? [];
        final pending = threads
            .where((thread) => thread.isPendingFor(profile.uid))
            .toList();
        final blocked = threads
            .where((thread) => thread.blockedBy.contains(profile.uid))
            .toList();
        final active = threads
            .where((thread) =>
                !thread.isPendingFor(profile.uid) &&
                !thread.blockedBy.contains(profile.uid))
            .toList();

        if (pending.isEmpty && active.isEmpty && blocked.isEmpty) {
          return const _ErrorNotice(
            icon: Icons.chat_bubble_outline,
            message:
                'No conversations yet. Reply to a feed or message a partner to get started.',
          );
        }

        return ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          children: [
            if (pending.isNotEmpty) ...[
              const _MessagesSectionHeader(title: 'Needing approval'),
              SizedBox(height: 8.h),
              ...pending.map(
                (thread) => _PendingThreadCard(
                  profile: profile,
                  thread: thread,
                ),
              ),
              SizedBox(height: 24.h),
            ],
            if (active.isNotEmpty) ...[
              const _MessagesSectionHeader(title: 'Conversations'),
              SizedBox(height: 8.h),
              ...active.map(
                (thread) => _ConversationCard(
                  profile: profile,
                  thread: thread,
                ),
              ),
              SizedBox(height: 24.h),
            ],
            if (blocked.isNotEmpty) ...[
              const _MessagesSectionHeader(title: 'Blocked conversations'),
              SizedBox(height: 8.h),
              ...blocked.map(
                (thread) => _ConversationCard(
                  profile: profile,
                  thread: thread,
                  showBlockedState: true,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MessagesSectionHeader extends StatelessWidget {
  const _MessagesSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _PendingThreadCard extends StatelessWidget {
  const _PendingThreadCard({
    required this.profile,
    required this.thread,
  });

  final UserProfile profile;
  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherId = thread.otherParticipant(profile.uid);
    final otherName =
        thread.participantNames[otherId] ?? 'KrishiConnect partner';
    final preview = thread.lastMessage ?? 'Awaiting your approval to chat.';
    final alreadyBlocked = profile.blockedUsers.contains(otherId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              otherName,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              preview,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _approve(context),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: () => alreadyBlocked
                      ? _unblock(context, otherId)
                      : _block(context, otherId),
                  icon: Icon(
                    alreadyBlocked ? Icons.lock_open : Icons.block,
                  ),
                  label: Text(alreadyBlocked ? 'Unblock' : 'Block'),
                ),
                TextButton(
                  onPressed: () => _viewProfile(context, otherId),
                  child: const Text('View profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = context.read<DatabaseService>();
    try {
      await db.approveThread(threadId: thread.id, approverId: profile.uid);
      messenger.showSnackBar(
        const SnackBar(content: Text('Conversation approved.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not approve: $e')),
      );
    }
  }

  Future<void> _block(BuildContext context, String otherId) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthService>();
    final db = context.read<DatabaseService>();
    try {
      await auth.blockUser(otherId);
      await db.markThreadBlocked(threadId: thread.id, blockerId: profile.uid);
      final name = thread.participantNames[otherId] ?? 'user';
      messenger.showSnackBar(
        SnackBar(content: Text('Blocked $name.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not block user: $e')),
      );
    }
  }

  Future<void> _unblock(BuildContext context, String otherId) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthService>();
    final db = context.read<DatabaseService>();
    try {
      await auth.unblockUser(otherId);
      await db.markThreadUnblocked(
        threadId: thread.id,
        blockerId: profile.uid,
      );
      final name = thread.participantNames[otherId] ?? 'user';
      messenger.showSnackBar(
        SnackBar(content: Text('Unblocked $name.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not unblock user: $e')),
      );
    }
  }

  void _viewProfile(BuildContext context, String uid) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfilePage(uid: uid)),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.profile,
    required this.thread,
    this.showBlockedState = false,
  });

  final UserProfile profile;
  final ChatThread thread;
  final bool showBlockedState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherId = thread.otherParticipant(profile.uid);
    final otherName =
        thread.participantNames[otherId] ?? 'KrishiConnect partner';
    final blockedByMe = thread.blockedBy.contains(profile.uid);
    final blockedByOther = thread.blockedBy.isNotEmpty && !blockedByMe;
    final showOtherNotice = showBlockedState && blockedByOther;
    final subtitle = blockedByMe
        ? 'You blocked this user. Unblock to resume the chat.'
        : thread.lastMessage ?? 'Tap to chat';

    return Card(
      color: showOtherNotice ? theme.colorScheme.surfaceVariant : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    blockedByMe
                        ? '$otherName (blocked)'
                        : showOtherNotice
                            ? '$otherName (blocked)'
                            : otherName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (!blockedByMe)
                  IconButton(
                    tooltip: 'Conversation options',
                    onPressed: () => _showMenu(context, otherId),
                    icon: const Icon(Icons.more_vert),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium,
            ),
            if (!blockedByMe)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openChat(context, otherId, otherName),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open chat'),
                ),
              ),
            if (blockedByMe)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _unblock(context, otherId),
                  child: const Text('Unblock'),
                ),
              ),
            if (blockedByMe)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _viewProfile(context, otherId),
                  child: const Text('View profile'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, String otherId) async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View profile'),
              onTap: () => Navigator.of(sheetContext).pop('profile'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block user'),
              onTap: () => Navigator.of(sheetContext).pop('block'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );

    switch (selection) {
      case 'profile':
        _viewProfile(context, otherId);
        break;
      case 'block':
        _block(context, otherId);
        break;
      default:
        break;
    }
  }

  Future<void> _block(BuildContext context, String otherId) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthService>();
    final db = context.read<DatabaseService>();
    try {
      await auth.blockUser(otherId);
      await db.markThreadBlocked(threadId: thread.id, blockerId: profile.uid);
      final name = thread.participantNames[otherId] ?? 'user';
      messenger.showSnackBar(
        SnackBar(content: Text('Blocked $name.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not block user: $e')),
      );
    }
  }

  Future<void> _unblock(BuildContext context, String otherId) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthService>();
    final db = context.read<DatabaseService>();
    try {
      await auth.unblockUser(otherId);
      await db.markThreadUnblocked(
        threadId: thread.id,
        blockerId: profile.uid,
      );
      final name = thread.participantNames[otherId] ?? 'user';
      messenger.showSnackBar(
        SnackBar(content: Text('Unblocked $name.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not unblock user: $e')),
      );
    }
  }

  void _openChat(
    BuildContext context,
    String otherId,
    String otherName,
  ) {
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
  }

  void _viewProfile(BuildContext context, String uid) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfilePage(uid: uid)),
    );
  }
}

class _FeedRecommendationSection extends StatelessWidget {
  const _FeedRecommendationSection({required this.profile});

  const _FeedRecommendationSection.emptyPlaceholder() : profile = null;

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Recommended for you',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text('No recommendations yet.'),
        ],
      );
    }

    final recommendationService = context.read<RecommendationService>();

    return FutureBuilder<List<FeedRecommendation>>(
      future: recommendationService.recommendFeedPosts(
        currentUser: profile!,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data ?? const [];
        if (data.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended for you',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12.h),
            ...data.map(
              (rec) => FeedPostCard(
                profile: profile!,
                post: rec.post,
                highlightReasons: rec.reasons,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CreatePostCard extends StatelessWidget {
  const _CreatePostCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
      child: ListTile(
        leading: const Icon(Icons.add_circle_outline),
        title: const Text('Create a new request'),
        subtitle: const Text('Share your demand so nearby farmers can respond.'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreateFeedPostPage(profile: profile),
          ),
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
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
    );
  }
}

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'just now';
}

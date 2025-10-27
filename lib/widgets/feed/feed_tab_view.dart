import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../models/chat_models.dart';
import '../../models/feed_post.dart';
import '../../models/user_model.dart';
import '../../services/db_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/profile_drawer.dart';
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
        if (posts.isEmpty && !ownPostsOnly) {
          return const _ErrorNotice(
            icon: Icons.dynamic_feed_outlined,
            message:
                'Market is quiet for now. Check back soon for new requests.',
          );
        }

        final list = List<FeedPost>.from(posts);
        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          itemCount: ownPostsOnly ? list.length + 1 : list.length,
          separatorBuilder: (_, __) => SizedBox(height: 16.h),
          itemBuilder: (context, index) {
            if (ownPostsOnly && index == 0) {
              return _CreatePostCard(profile: profile);
            }
            final post = ownPostsOnly ? list[index - 1] : list[index];
            return FeedPostCard(profile: profile, post: post);
          },
        );
      },
    );
  }
}

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({super.key, required this.profile, required this.post});

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
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserProfilePage(uid: post.authorId),
                    ),
                  ),
                  child: const Text('View profile'),
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
        if (threads.isEmpty) {
          return const _ErrorNotice(
            icon: Icons.chat_bubble_outline,
            message:
                'No conversations yet. Reply to a feed or message a partner to get started.',
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

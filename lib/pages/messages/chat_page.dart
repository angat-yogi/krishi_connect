import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_models.dart';
import '../../services/db_service.dart';
import '../../widgets/loading_view.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.threadId,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherDisplayName,
  });

  final String threadId;
  final String currentUserId;
  final String otherUserId;
  final String otherDisplayName;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherDisplayName),
      ),
      body: StreamBuilder<ChatThread?>(
        stream: db.listenThread(widget.threadId),
        builder: (context, threadSnapshot) {
          if (threadSnapshot.hasError) {
            return const Center(child: Text('Conversation unavailable.'));
          }
          if (threadSnapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final thread = threadSnapshot.data;
          if (thread == null) {
            return const Center(child: Text('Conversation no longer exists.'));
          }

          final isPending = thread.isPendingFor(widget.currentUserId);
          final blockedByMe = thread.blockedBy.contains(widget.currentUserId);
          final blockedByOther =
              thread.blockedBy.isNotEmpty && !blockedByMe;
          final canSend = !isPending && !blockedByMe && !blockedByOther;

          final statusText = blockedByOther
              ? 'This user has blocked you. You can view past messages but cannot reply.'
              : blockedByMe
                  ? 'You blocked this user. Unblock them from Messages to continue chatting.'
                  : isPending
                      ? 'Approve this conversation from Messages to reply.'
                      : null;

          return Column(
            children: [
              if (statusText != null)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: db.listenMessages(widget.threadId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Unable to load messages.'),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingView();
                    }
                    final messages = snapshot.data ?? [];
                    if (messages.isEmpty) {
                      return const Center(
                        child: Text('Start the conversation…'),
                      );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == widget.currentUserId;
                        return Align(
                          alignment:
                              isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: canSend && !_isSending,
                          textInputAction: TextInputAction.send,
                          onSubmitted:
                              canSend ? (_) => _sendMessage(context) : null,
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: (!canSend || _isSending)
                            ? null
                            : () => _sendMessage(context),
                        child: _isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendMessage(BuildContext context) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await context.read<DatabaseService>().sendMessage(
            threadId: widget.threadId,
            senderId: widget.currentUserId,
            text: text,
          );
      _messageController.clear();
    } on MessagingException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

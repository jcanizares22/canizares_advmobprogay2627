import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    required this.currentUserId,
    required this.currentUserEmail,
    required this.otherUser,
    super.key,
  });

  final String currentUserId;
  final String currentUserEmail;
  final UserModel otherUser;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final Set<String> _receiptUpdatesInProgress = {};
  final Map<String, ChatMessage> _localPendingMessages = {};
  late final String _conversationId;
  late final Future<void> _conversationFuture;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _conversationId = _chatService.conversationIdFor(
      widget.currentUserId,
      widget.otherUser.uid,
    );
    _conversationFuture = _chatService.ensureConversation(
      currentUserId: widget.currentUserId,
      otherUserId: widget.otherUser.uid,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName(widget.otherUser);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Text(
                _initials(displayName),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (widget.otherUser.email.isNotEmpty)
                    Text(
                      widget.otherUser.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<void>(
        future: _conversationFuture,
        builder: (context, conversationSnapshot) {
          if (conversationSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not open this chat: ${conversationSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (conversationSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _chatService.messagesStream(_conversationId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load messages: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!.docs
                        .map(ChatMessage.fromDocument)
                        .toList();
                    _scheduleReadReceipts(messages);
                    final messageById = {
                      for (final message in messages) message.id: message,
                      ..._localPendingMessages,
                    };
                    final displayedMessages = messageById.values.toList()
                      ..sort(
                        (first, second) =>
                            second.timestamp.compareTo(first.timestamp),
                      );

                    if (displayedMessages.isEmpty) {
                      return const Center(
                        child: Text('Start the conversation with a message.'),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                      itemCount: displayedMessages.length,
                      itemBuilder: (context, index) {
                        final message = displayedMessages[index];
                        return _AnimatedMessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          isCurrentUser:
                              message.senderId == widget.currentUserId,
                        );
                      },
                    );
                  },
                ),
              ),
              _buildComposer(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !_isSending,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!_isSending) unawaited(_sendMessage());
                },
                decoration: InputDecoration(
                  hintText: 'Message',
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: _isSending ? 'Sending…' : 'Send message',
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    final messageId = _chatService.newMessageId(_conversationId);
    final timestamp = DateTime.now();
    final pendingMessage = ChatMessage.pending(
      id: messageId,
      senderId: widget.currentUserId,
      senderEmail: widget.currentUserEmail,
      receiverId: widget.otherUser.uid,
      message: messageText,
      timestamp: timestamp,
    );

    setState(() {
      _isSending = true;
      _localPendingMessages[messageId] = pendingMessage;
    });
    _messageController.clear();
    try {
      await _chatService.sendMessage(
        conversationId: _conversationId,
        messageId: messageId,
        senderId: widget.currentUserId,
        receiverId: widget.otherUser.uid,
        message: messageText,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _localPendingMessages.remove(messageId));
      _messageController.text = messageText;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message could not be sent: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
    if (!mounted) return;
    setState(() {
      _localPendingMessages.remove(messageId);
    });
  }

  void _scheduleReadReceipts(List<ChatMessage> messages) {
    final incoming = messages
        .where(
          (message) =>
              message.receiverId == widget.currentUserId &&
              message.status != ChatMessageStatus.seen &&
              !_receiptUpdatesInProgress.contains(message.id),
        )
        .toList();
    if (incoming.isEmpty) return;

    final ids = incoming.map((message) => message.id).toList();
    _receiptUpdatesInProgress.addAll(ids);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _chatService.markMessagesDelivered(
          conversationId: _conversationId,
          currentUserId: widget.currentUserId,
          messageIds: ids,
        );
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        await _chatService.markMessagesSeen(
          conversationId: _conversationId,
          currentUserId: widget.currentUserId,
          messageIds: ids,
        );
      } catch (error) {
        _receiptUpdatesInProgress.removeAll(ids);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Read receipt could not be updated: $error'),
            ),
          );
        }
      }
    });
  }

  String _displayName(UserModel user) {
    final fullName = '${user.firstName} ${user.lastName}'.trim();
    if (fullName.isNotEmpty) return fullName;
    if (user.username.trim().isNotEmpty) return user.username.trim();
    return user.email.isNotEmpty ? user.email : 'User';
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return '${words.first.characters.first}${words.last.characters.first}'
        .toUpperCase();
  }
}

class _AnimatedMessageBubble extends StatelessWidget {
  const _AnimatedMessageBubble({
    required this.message,
    required this.isCurrentUser,
    super.key,
  });

  final ChatMessage message;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bubbleColor = isCurrentUser
        ? colors.primary
        : colors.surfaceContainerHighest;
    final foregroundColor = isCurrentUser ? colors.onPrimary : colors.onSurface;
    final statusColor = message.status == ChatMessageStatus.seen
        ? Colors.lightBlueAccent
        : foregroundColor.withValues(alpha: 0.72);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset((isCurrentUser ? 16 : -16) * (1 - progress), 0),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(
                    alpha: isCurrentUser ? 0.10 : 0.04,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isCurrentUser ? 18 : 4),
                bottomRight: Radius.circular(isCurrentUser ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.message,
                  style: TextStyle(color: foregroundColor, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        color: foregroundColor.withValues(alpha: 0.72),
                        fontSize: 10,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        ),
                        child: Row(
                          key: ValueKey(message.status),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MessageStatusIcon(
                              status: message.status,
                              color: statusColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _statusLabel(message.status),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _statusLabel(ChatMessageStatus status) {
    return switch (status) {
      ChatMessageStatus.sending => 'Sending…',
      ChatMessageStatus.sent => 'Sent',
      ChatMessageStatus.delivered => 'Delivered',
      ChatMessageStatus.seen => 'Seen',
    };
  }
}

class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon({required this.status, required this.color});

  final ChatMessageStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ChatMessageStatus.sending => Semantics(
        label: 'Sending message',
        child: SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
      ChatMessageStatus.sent => Icon(
        Icons.check,
        size: 14,
        color: color,
        semanticLabel: 'Sent',
      ),
      ChatMessageStatus.delivered || ChatMessageStatus.seen => Icon(
        Icons.done_all,
        size: 14,
        color: color,
        semanticLabel: status == ChatMessageStatus.seen ? 'Seen' : 'Delivered',
      ),
    };
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:dance_pulse/app/controllers/auth_controller.dart';
import 'package:dance_pulse/app/modules/home_feed/feed_controller.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';
import 'package:dance_pulse/app/data/models/dance_models.dart';
import 'package:dance_pulse/app/utils/app_strings.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _formatListTime(DateTime utc) {
    final local = utc.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return DateFormat('hh:mm a').format(local);
    if (diff < 7) return DateFormat('EEE').format(local);
    return DateFormat('MMM d').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FeedController>(
      builder: (feedController) {
        final authService = Get.find<AuthController>();
        final currentUser = authService.currentUserProfile;
        final chatRooms = feedController.chatRooms;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: const Text(MessagesStrings.inbox),
            centerTitle: false,
            actions: [IconButton(icon: const Icon(Icons.edit_note_rounded), onPressed: () {})],
          ),
          body: currentUser == null
              ? const Center(child: Text(MessagesStrings.signInPrompt))
              : RefreshIndicator(
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.cardBg,
                  onRefresh: () async {
                    await feedController.refreshData();
                  },
                  child: chatRooms.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: constraints.maxHeight,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.textSecondary),
                                    SizedBox(height: 12),
                                    Text(MessagesStrings.noMessagesYet, style: TextStyle(color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            );
                          }
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: chatRooms.length,
                          separatorBuilder: (context, index) =>
                              Divider(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, indent: 80, height: 1),
                          itemBuilder: (context, index) {
                            final room = chatRooms[index];
                            final lastMsg = room.lastMessage;
                            final isOnline = feedController.isUserOnline(room.otherUser.uid);
                            final unreadCount = feedController.getUnreadCount(room.id);

                            return ListTile(
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).push(MaterialPageRoute(builder: (context) => ChatRoomScreen(chatRoomId: room.id))).then((_) {
                                  feedController.safeUpdate();
                                });
                              },
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundImage: NetworkImage(
                                      room.otherUser.avatarUrl,
                                      headers: SupabaseStore.getHeadersForUrl(room.otherUser.avatarUrl),
                                    ),
                                  ),
                                  if (isOnline)
                                    Positioned(
                                      bottom: 0,
                                      right: 2,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2.0),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    room.otherUser.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  if (room.otherUser.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, size: 14, color: AppTheme.accent),
                                  ],
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  lastMsg?.text ?? MessagesStrings.startConversation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unreadCount > 0
                                        ? (isDark ? Colors.white : Colors.black)
                                        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    lastMsg != null ? _formatListTime(lastMsg.timestamp) : "",
                                    style: TextStyle(
                                      color: unreadCount > 0
                                          ? AppTheme.primary
                                          : (isDark
                                                ? AppTheme.darkTextSecondary.withValues(alpha: 0.6)
                                                : AppTheme.lightTextSecondary.withValues(alpha: 0.6)),
                                      fontSize: 11,
                                      fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  if (unreadCount > 0) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                      child: Text(
                                        "$unreadCount",
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
        );
      },
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  final String chatRoomId;

  const ChatRoomScreen({super.key, required this.chatRoomId});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _msgCount = 0;
  Timer? _typingTimer;

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateHeader(DateTime local) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(local);
    return DateFormat('MMM d, yyyy').format(local);
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);

    final feedController = Get.find<FeedController>();
    feedController.activeChatRoomId = widget.chatRoomId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        feedController.markAsRead(widget.chatRoomId);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _onTextChanged() {
    final feedController = Get.find<FeedController>();
    final isNotEmpty = _messageController.text.trim().isNotEmpty;
    if (isNotEmpty) {
      feedController.updateTypingStatus(true, widget.chatRoomId);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        feedController.updateTypingStatus(false, widget.chatRoomId);
      });
    } else {
      _typingTimer?.cancel();
      feedController.updateTypingStatus(false, widget.chatRoomId);
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    try {
      final feedController = Get.find<FeedController>();
      feedController.updateTypingStatus(false, widget.chatRoomId);
      if (feedController.activeChatRoomId == widget.chatRoomId) {
        feedController.activeChatRoomId = null;
      }
      feedController.markAsRead(widget.chatRoomId);
    } catch (_) {}
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(FeedController feedController, String currentUserId) {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      feedController.sendMessage(widget.chatRoomId, text, currentUserId);
      _messageController.clear();

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _showMessageOptions(
    BuildContext context,
    FeedController feedController,
    ChatMessage message,
    String chatRoomId,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.accent),
              title: const Text('Edit message'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(context, feedController, message, chatRoomId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Delete message', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                feedController.deleteMessage(chatRoomId, message.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, FeedController feedController, ChatMessage message, String chatRoomId) {
    final editController = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardBg : Colors.white,
        title: const Text('Edit message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: null,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != message.text) {
                feedController.editMessage(chatRoomId, message.id, newText);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FeedController>(
      builder: (feedController) {
        final authService = Get.find<AuthController>();
        final currentUser = authService.currentUserProfile;

        final roomIndex = feedController.chatRooms.indexWhere((r) => r.id == widget.chatRoomId);
        if (roomIndex == -1 || currentUser == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text(MessagesStrings.conversationNotFound)),
          );
        }

        final room = feedController.chatRooms[roomIndex];
        final messages = room.messages;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (messages.length > _msgCount) {
          _msgCount = messages.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(
                    room.otherUser.avatarUrl,
                    headers: SupabaseStore.getHeadersForUrl(room.otherUser.avatarUrl),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          room.otherUser.displayName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        if (room.otherUser.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 12, color: AppTheme.accent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      feedController.isUserOnline(room.otherUser.uid)
                          ? MessagesStrings.online
                          : feedController.getUserLastSeen(room.otherUser.uid),
                      style: TextStyle(
                        fontSize: 10,
                        color: feedController.isUserOnline(room.otherUser.uid)
                            ? Colors.green
                            : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                        fontWeight: feedController.isUserOnline(room.otherUser.uid)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
              IconButton(icon: const Icon(Icons.phone_outlined), onPressed: () {}),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser.uid;
                    final localTime = message.timestamp.toLocal();
                    final timeStr = DateFormat('hh:mm a').format(localTime);

                    // Show date header when date changes between messages
                    final showDateHeader =
                        index == 0 || !_isSameDay(messages[index - 1].timestamp.toLocal(), localTime);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDateHeader)
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formatDateHeader(localTime),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onLongPress: isMe
                                    ? () => _showMessageOptions(context, feedController, message, widget.chatRoomId)
                                    : null,
                                child: Container(
                                  margin: const EdgeInsets.only(top: 2, bottom: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                  decoration: BoxDecoration(
                                    color: isMe ? AppTheme.primary : (isDark ? AppTheme.darkCardBg : Colors.grey[200]),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    message.text,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (message.isEdited) ...[
                                      Text(
                                        'edited · ',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                          color: (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (feedController.isUserTypingInRoom(room.otherUser.uid, widget.chatRoomId))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        MessagesStrings.isTyping(room.otherUser.displayName),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),

              // Send box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBackground : AppTheme.lightCardBg,
                  border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image_outlined, color: AppTheme.primary),
                        onPressed: () {},
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCardBg : Colors.grey[100],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: MessagesStrings.typeMessage,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (val) => _sendMessage(feedController, currentUser.uid),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _sendMessage(feedController, currentUser.uid),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

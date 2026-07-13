import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:dance_pulse/app/ui/theme/app_theme.dart';
import 'package:dance_pulse/app/modules/live_stream/live_stream_controller.dart';
import 'package:dance_pulse/app/data/models/dance_models.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';

class LiveViewerScreen extends StatefulWidget {
  final LiveStreamSession session;

  const LiveViewerScreen({super.key, required this.session});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  final controller = Get.find<LiveStreamController>();
  final textController = TextEditingController();
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller.joinStream(widget.session);

    // Auto scroll chat to bottom
    controller.currentChatMessages.listen((_) {
      if (scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    textController.dispose();
    scrollController.dispose();
    controller.leaveStream();
    super.dispose();
  }

  void _leaveStream() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // Cleanup is handled in dispose()
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Obx(() {
          return Stack(
            children: [
              // 1. Live Video Feed (WebRTC)
              Positioned.fill(
                child: controller.isWebRTCInitialized.value
                    ? webrtc.RTCVideoView(
                        controller.remoteRenderer,
                        objectFit: webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Container(
                        color: Colors.black87,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: AppTheme.primary),
                              SizedBox(height: 16),
                              Text("Connecting to live stream...", style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
              ),

              // Dark overlay gradient to make text legible
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.2, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // 2. Stream Header
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // LIVE Red Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        "LIVE",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Stream type Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "BATTLE LIVE STREAM",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Viewer Count
                    GestureDetector(
                      onTap: () => controller.showViewerList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: [
                            const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              "${controller.viewerCount.value}",
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: _leaveStream,
                    ),
                  ],
                ),
              ),

              // Stream Title description
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.session.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Hosted by @${widget.session.hostName}",
                        style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Chat Messages Overlay
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 84,
                left: 12,
                right: 80,
                height: 280,
                child: Obx(() {
                  final messages = controller.currentChatMessages;
                  if (messages.isEmpty) return const SizedBox.shrink();
                  return ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white],
                        stops: [0.0, 0.25],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: messages.length,
                      padding: const EdgeInsets.only(top: 8),
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Avatar
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.6), width: 1.5),
                                ),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppTheme.cardBg,
                                  backgroundImage: NetworkImage(
                                    msg.senderAvatar,
                                    headers: SupabaseStore.getHeadersForUrl(msg.senderAvatar),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Message Bubble
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(4),
                                    ),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Sender name with gradient shimmer
                                      ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          colors: [AppTheme.primary, AppTheme.accent],
                                        ).createShader(bounds),
                                        child: Text(
                                          msg.senderName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      // Message text
                                      Text(
                                        msg.messageText,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),

              // 4. Chat Input Box
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                left: 12,
                right: 12,
                child: _ChatInputBar(
                  textController: textController,
                  onSend: () {
                    if (textController.text.trim().isNotEmpty) {
                      controller.sendChatMessage(textController.text.trim());
                      textController.clear();
                    }
                  },
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// ─── Reusable Chat Input Bar ───────────────────────────────────────────────
class _ChatInputBar extends StatefulWidget {
  final TextEditingController textController;
  final VoidCallback onSend;

  const _ChatInputBar({required this.textController, required this.onSend});

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _isFocused ? AppTheme.primary.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.15),
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow: _isFocused
            ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: 1)]
            : [],
      ),
      child: Row(
        children: [
          // Emoji icon
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(Icons.emoji_emotions_outlined, color: _isFocused ? AppTheme.accent : Colors.white38, size: 20),
          ),
          const SizedBox(width: 6),
          // Text field
          Expanded(
            child: TextField(
              controller: widget.textController,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => widget.onSend(),
              decoration: const InputDecoration(
                hintText: "Say something...",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // Send button
          GestureDetector(
            onTap: widget.onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:firebasecrashreport/app/ui/theme/app_theme.dart';
import 'package:firebasecrashreport/app/modules/live_stream/live_stream_controller.dart';
import 'package:firebasecrashreport/app/data/services/supabase_store.dart';

class LiveHostScreen extends StatefulWidget {
  final String streamTitle;

  const LiveHostScreen({super.key, required this.streamTitle});

  @override
  State<LiveHostScreen> createState() => _LiveHostScreenState();
}

class _LiveHostScreenState extends State<LiveHostScreen> {
  final controller = Get.find<LiveStreamController>();
  final textController = TextEditingController();
  final scrollController = ScrollController();
  bool _canLeave = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.initializeHostCamera();
      await controller.startStream(widget.streamTitle);
    });

    // Auto scroll chat to bottom when new messages arrive
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
    controller.stopStream();
    super.dispose();
  }

  void _confirmEndStream() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text(
          "End Live Stream?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to end your live stream? This will disconnect all viewers.",
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await controller.stopStream();
              if (mounted) {
                setState(() {
                  _canLeave = true;
                });
                Navigator.of(this.context).pop();
              }
            },
            child: const Text(
              "End Stream",
              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canLeave,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _confirmEndStream();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Obx(() {
          final isCameraInit = controller.isCameraInitialized.value;

          return Stack(
            children: [
              // 1. Camera View Finder
              Positioned.fill(
                child: isCameraInit
                    ? webrtc.RTCVideoView(
                        controller.localRenderer,
                        objectFit: webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        mirror: true,
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppTheme.primary),
                            SizedBox(height: 16),
                            Text(
                              "Initializing camera stream...",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
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
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
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
                        color: AppTheme.primary.withOpacity(0.85),
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
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
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
                      onPressed: _confirmEndStream,
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
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.streamTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),

              // Camera & Microphone Controls
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                right: 16,
                child: Column(
                  children: [
                    // Mute microphone
                    Obx(() {
                      final isMuted = controller.isMuted.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            isMuted ? Icons.mic_off : Icons.mic,
                            color: isMuted ? Colors.redAccent : Colors.white,
                            size: 22,
                          ),
                          onPressed: () => controller.toggleMute(),
                        ),
                      );
                    }),
                    // Flip camera
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () => controller.switchCamera(),
                      ),
                    ),
                  ],
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
                                  border: Border.all(
                                    color: AppTheme.primary.withOpacity(0.6),
                                    width: 1.5,
                                  ),
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
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(4),
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                      width: 1,
                                    ),
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
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          height: 1.3,
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
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _isFocused
              ? AppTheme.primary.withOpacity(0.8)
              : Colors.white.withOpacity(0.15),
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Emoji icon
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(
              Icons.emoji_emotions_outlined,
              color: _isFocused ? AppTheme.accent : Colors.white38,
              size: 20,
            ),
          ),
          const SizedBox(width: 6),
          // Text field
          Expanded(
            child: TextField(
              controller: widget.textController,
              focusNode: _focusNode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
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
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
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

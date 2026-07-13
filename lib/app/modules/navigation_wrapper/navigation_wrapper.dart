import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dance_pulse/app/modules/home_feed/home_feed_screen.dart';
import 'package:dance_pulse/app/modules/discovery/discovery_screen.dart';
import 'package:dance_pulse/app/modules/create_post/instagram_media_picker_screen.dart';
import 'package:dance_pulse/app/modules/messages/messages_screen.dart';
import 'package:dance_pulse/app/modules/profile/profile_screen.dart';
import 'package:dance_pulse/app/modules/battle/battle_matching_screen.dart';
import 'package:dance_pulse/app/modules/live_stream/live_host_screen.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';
import 'package:dance_pulse/app/modules/home_feed/feed_controller.dart';
import 'package:dance_pulse/app/modules/navigation_wrapper/navigation_controller.dart';
import 'package:dance_pulse/app/utils/app_strings.dart';

class NavigationWrapper extends StatelessWidget {
  const NavigationWrapper({super.key});

  void _showGoLiveDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Start a Live Stream",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit'),
          ),
          content: TextField(
            controller: titleController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: "Enter stream title (e.g. Freestyle Battle)",
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  Navigator.of(context).pop();
                  Get.to(() => LiveHostScreen(streamTitle: title));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Go Live"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final NavigationController navigationController = Get.put(NavigationController());

    final List<Widget> screens = [
      const HomeFeedScreen(),
      const DiscoveryScreen(),
      const SizedBox.shrink(), // Placeholder for the middle Plus button
      const MessagesScreen(),
      const ProfileScreen(),
    ];

    void openCreatePostModal() {
      InstagramMediaPickerScreen.show(context, isFromCreatePost: false);
    }

    void openBattleArenaMatchmaking() {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const BattleMatchingScreen()));
    }

    void showCreateOptionsBottomSheet() {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppTheme.border, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                const Text(
                  NavigationStrings.chooseAction,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                ),
                const SizedBox(height: 24),

                // Option 1: Create Post (Card)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    openCreatePostModal();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                          child: const Icon(Icons.video_call_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              NavigationStrings.createPost,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              NavigationStrings.createPostDesc,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Option: Go Live (Card)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _showGoLiveDialog(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                          child: const Icon(Icons.videocam_rounded, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Go Live",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Start a live broadcast to show your moves",
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 20),

                // Option 2: Slide to Battle (Slider Button)
                SlideToBattleButton(
                  onSwiped: () async {
                    Navigator.of(context).pop();

                    // Request camera and microphone permissions first
                    final statuses = await [Permission.camera, Permission.microphone].request();

                    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
                    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;

                    if (cameraGranted && micGranted) {
                      openBattleArenaMatchmaking();
                    } else {
                      Get.snackbar(
                        NavigationStrings.permissionsRequired,
                        NavigationStrings.permissionsRequiredDesc,
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                        colorText: Colors.white,
                        duration: const Duration(seconds: 5),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    }

    void onTabTapped(int index) {
      if (index == 2) {
        showCreateOptionsBottomSheet();
      } else {
        navigationController.changeIndex(index);
      }
    }

    return Obx(() {
      final currentIndex = navigationController.currentIndex.value;
      final unread = Get.find<FeedController>().unreadCountRx.value;

      return Scaffold(
        body: Stack(
          children: [
            IndexedStack(index: currentIndex, children: screens),
            const _UploadProgressOverlay(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTabTapped,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: 'Discover',
              ),
              // Custom Center Plus Button Item
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Container(
                    height: 38,
                    width: 50,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppTheme.textPrimary),
                    child: Stack(
                      children: [
                        // Cyan wing
                        Positioned(
                          left: -3,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 20,
                            decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        // Pink wing
                        Positioned(
                          right: -3,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 20,
                            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        // White center container
                        Center(
                          child: Container(
                            height: 38,
                            width: 42,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.add, color: Colors.black, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text("$unread", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                  backgroundColor: AppTheme.primary,
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                activeIcon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text("$unread", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                  backgroundColor: AppTheme.primary,
                  child: const Icon(Icons.chat_bubble_rounded),
                ),
                label: 'Inbox',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Standalone widget for the upload progress overlay.
/// Uses its own GetBuilder so it NEVER contaminates the outer Obx context.
class _UploadProgressOverlay extends StatelessWidget {
  const _UploadProgressOverlay();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FeedController>(
      builder: (feedController) {
        final queue = feedController.uploadQueue;
        final activeTask = feedController.activeUploadTask;

        if (activeTask == null) return const SizedBox.shrink();

        return Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: GestureDetector(
            onTap: activeTask.status == "Failed" ? () => feedController.retryTask(activeTask.id) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: activeTask.status == "Failed" ? Colors.redAccent.withValues(alpha: 0.8) : AppTheme.border,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (activeTask.status == "Uploading")
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                        )
                      else if (activeTask.status == "Failed")
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20)
                      else if (activeTask.status == "Completed")
                        const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20)
                      else
                        const Icon(Icons.hourglass_empty_rounded, color: AppTheme.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeTask.status == "Uploading"
                                  ? (activeTask.isBattle ? "Uploading Battle..." : NavigationStrings.uploadingPost)
                                  : activeTask.status == "Failed"
                                  ? (activeTask.isBattle ? "Battle Upload Failed" : NavigationStrings.uploadFailed)
                                  : activeTask.status == "Completed"
                                  ? (activeTask.isBattle ? "Battle Completed! 🔥" : NavigationStrings.uploadSuccessful)
                                  : NavigationStrings.waitingInQueue,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeTask.currentStep,
                              style: TextStyle(
                                fontSize: 11,
                                color: activeTask.status == "Failed" ? Colors.redAccent : AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (activeTask.status != "Failed") ...[
                        Text(
                          "${(activeTask.progress * 100).toInt()}%",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Close/Dismiss button
                      GestureDetector(
                        onTap: () => feedController.cancelTask(activeTask.id),
                        child: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: activeTask.progress,
                      backgroundColor: AppTheme.border,
                      color: activeTask.status == "Failed"
                          ? Colors.redAccent
                          : (activeTask.status == "Completed" ? Colors.green : AppTheme.primary),
                      minHeight: 4,
                    ),
                  ),
                  if (queue.length > 1) ...[
                    const SizedBox(height: 8),
                    Text(
                      NavigationStrings.morePostsInQueue(queue.length - 1),
                      style: const TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SlideToBattleButton extends StatelessWidget {
  final VoidCallback onSwiped;
  final RxDouble _dragPosition = 0.0.obs;
  final RxBool _isFinished = false.obs;

  SlideToBattleButton({super.key, required this.onSwiped});

  @override
  Widget build(BuildContext context) {
    const double buttonHeight = 56.0;
    const double handleSize = 48.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - handleSize - 8.0;

        return Obx(() {
          return Container(
            width: double.infinity,
            height: buttonHeight,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.border),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Sliding text prompt
                Center(
                  child: Opacity(
                    opacity: (1.0 - (_dragPosition.value / maxDrag)).clamp(0.1, 1.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          NavigationStrings.slideToBattle,
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.5,
                            shadows: [Shadow(color: AppTheme.accent.withValues(alpha: 0.5), blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_double_arrow_right_rounded, color: AppTheme.accent, size: 16),
                      ],
                    ),
                  ),
                ),
                // Drag handle
                Positioned(
                  left: _dragPosition.value + 4,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_isFinished.value) return;
                      _dragPosition.value = (_dragPosition.value + details.delta.dx).clamp(0.0, maxDrag);
                    },
                    onHorizontalDragEnd: (details) {
                      if (_isFinished.value) return;
                      if (_dragPosition.value >= maxDrag * 0.85) {
                        // Trigger action
                        _dragPosition.value = maxDrag;
                        _isFinished.value = true;
                        onSwiped();
                        // Reset after short delay
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _dragPosition.value = 0.0;
                          _isFinished.value = false;
                        });
                      } else {
                        // Snaps back
                        _dragPosition.value = 0.0;
                      }
                    },
                    child: Container(
                      width: handleSize,
                      height: handleSize,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1),
                        ],
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

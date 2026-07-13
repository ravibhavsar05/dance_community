import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:dance_pulse/app/data/models/dance_models.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';
import 'package:dance_pulse/app/modules/home_feed/feed_controller.dart';

class VideoFeedItemController extends GetxController with GetSingleTickerProviderStateMixin {
  final DanceClip clip;
  VideoFeedItemController({required this.clip});

  VideoPlayerController? videoController;
  late AnimationController vinylAnimationController;
  final isInitialized = false.obs;
  final hasError = false.obs;
  final isSeekingRange = false.obs;
  final isPlaying = false.obs;

  // Comments
  final comments = <Comment>[].obs;
  final isLoadingComments = false.obs;

  /// True when this clip's current primary media is a video.
  /// For multi-media posts we check the first item; for single-media we fall back to URL sniffing.
  bool get isVideo {
    final items = clip.mediaItems;
    if (items.isNotEmpty) {
      return items.first['type'] == 'video';
    }
    return clip.videoUrl.contains('.m3u8') || clip.videoUrl.contains('.mp4');
  }

  Worker? _muteWorker;

  @override
  void onInit() {
    super.onInit();
    vinylAnimationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _initializeVideo();

    final feedController = Get.find<FeedController>();
    _muteWorker = ever(feedController.isMuted, (bool muted) {
      if (videoController != null && isInitialized.value) {
        videoController!.setVolume(muted ? 0.0 : 1.0);
      }
    });
  }

  void _videoListener() {
    if (videoController == null || isSeekingRange.value) return;

    final position = videoController!.value.position.inMilliseconds;
    final start = clip.startTimeMs;
    final end = clip.endTimeMs;

    if (end > start) {
      if (position >= end || position < start) {
        isSeekingRange.value = true;
        videoController!.seekTo(Duration(milliseconds: start)).then((_) {
          isSeekingRange.value = false;
        });
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (!isVideo) return;
    try {
      if (clip.videoUrl.startsWith('http://') || clip.videoUrl.startsWith('https://')) {
        videoController = VideoPlayerController.networkUrl(
          Uri.parse(clip.videoUrl),
          httpHeaders: SupabaseStore.getHeadersForUrl(clip.videoUrl) ?? const {},
        );
      } else {
        videoController = VideoPlayerController.file(File(clip.videoUrl));
      }
      final feedController = Get.find<FeedController>();
      await videoController!.initialize();
      await videoController!.setVolume(feedController.isMuted.value ? 0.0 : 1.0);

      final start = clip.startTimeMs;
      final end = clip.endTimeMs;

      if (end > start) {
        videoController!.setLooping(false);
        videoController!.addListener(_videoListener);
        await videoController!.seekTo(Duration(milliseconds: start));
      } else {
        videoController!.setLooping(true);
      }

      isInitialized.value = true;
      final index = feedController.clips.indexWhere((c) => c.id == clip.id);
      if (index == feedController.focusedIndex.value) {
        videoController!.play();
        isPlaying.value = true;
        vinylAnimationController.repeat();
      } else {
        isPlaying.value = videoController!.value.isPlaying;
      }
    } catch (e) {
      debugPrint("Video init failed for ${clip.id}: $e");
      hasError.value = true;
    }
  }

  void setFocus(bool focus) {
    if (!isVideo || videoController == null || !isInitialized.value) return;
    if (focus) {
      videoController!.play();
      isPlaying.value = true;
      vinylAnimationController.repeat();
    } else {
      videoController!.pause();
      isPlaying.value = false;
      vinylAnimationController.stop();
    }
  }

  void togglePlayPause() {
    if (!isVideo || videoController == null || !isInitialized.value) return;
    if (videoController!.value.isPlaying) {
      videoController!.pause();
      isPlaying.value = false;
      vinylAnimationController.stop();
    } else {
      videoController!.play();
      isPlaying.value = true;
      vinylAnimationController.repeat();
    }
  }

  Future<void> loadComments() async {
    isLoadingComments.value = true;
    try {
      final results = await Get.find<FeedController>().getComments(clip.id);
      comments.value = results;
    } catch (e) {
      debugPrint("Error fetching comments: $e");
    } finally {
      isLoadingComments.value = false;
    }
  }

  Future<void> submitComment(String commentText, DancerProfile user) async {
    try {
      await Get.find<FeedController>().addComment(clip.id, commentText, user);
      await loadComments(); // reload comments
    } catch (e) {
      debugPrint("Error adding comment: $e");
    }
  }

  @override
  void onClose() {
    _muteWorker?.dispose();
    videoController?.removeListener(_videoListener);
    videoController?.dispose();
    vinylAnimationController.dispose();
    super.onClose();
  }
}

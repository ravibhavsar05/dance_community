import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:dance_pulse/app/controllers/auth_controller.dart';
import 'package:dance_pulse/app/modules/home_feed/feed_controller.dart';
import 'package:dance_pulse/app/utils/app_strings.dart';
import 'package:dance_pulse/app/modules/video_editor/video_editor_screen.dart';
import 'package:dance_pulse/app/modules/image_editor/image_editor_screen.dart';

class SelectedMediaItem {
  final String id;
  final XFile file;
  final String type; // "video" or "image"

  final cropAspectRatio = "9:16".obs; // "9:16", "1:1", "4:5"
  final isCropped = false.obs;
  final selectedFilter = "none".obs;
  final brightness = 1.0.obs;
  final startTimeSec = 0.0.obs;
  final endTimeSec = 15.0.obs;
  final videoDurationSec = 15.0.obs;
  final rotation = 0.obs; // 0, 1, 2, 3 (quarter turns)
  final originalAspectRatio = 1.0.obs;

  // Visual crop coordinates
  final scale = 1.0.obs;
  final panX = 0.0.obs;
  final panY = 0.0.obs;

  // Visual crop coordinates
  // scale, panX, panY
  // ...
  SelectedMediaItem({required this.id, required this.file, required this.type, double duration = 15.0}) {
    videoDurationSec.value = duration;
    endTimeSec.value = duration;
    _initAspectRatio();
  }

  Future<void> _initAspectRatio() async {
    if (file.path.isEmpty) return;
    try {
      if (type == "video") {
        final controller = VideoPlayerController.file(File(file.path));
        await controller.initialize();
        originalAspectRatio.value = controller.value.aspectRatio;
        await controller.dispose();
      } else {
        final completer = Completer<double>();
        final image = Image.file(File(file.path));
        image.image
            .resolve(const ImageConfiguration())
            .addListener(
              ImageStreamListener(
                (ImageInfo info, bool _) {
                  final double ar = info.image.width / info.image.height;
                  if (!completer.isCompleted) completer.complete(ar);
                },
                onError: (dynamic exception, StackTrace? stackTrace) {
                  if (!completer.isCompleted) completer.complete(1.0);
                },
              ),
            );
        originalAspectRatio.value = await completer.future;
      }
    } catch (_) {
      originalAspectRatio.value = 1.0;
    }
  }
}

class CreatePostController extends GetxController {
  final captionController = TextEditingController();

  final selectedStyle = "Hip Hop".obs;
  final selectedMusic = "Obsession (Remix)".obs;
  final postType = "video".obs; // Kept for backward compatibility

  final selectedMediaItems = <SelectedMediaItem>[].obs;

  final List<String> danceStyles = ["Hip Hop", "Shuffle", "Krump", "Breaking", "Salsa", "Popping", "Contemporary"];
  final List<Map<String, String>> musicList = [
    {"name": "Obsession (Remix)", "artist": "DJ Retro"},
    {"name": "Heavy Hitter Drums", "artist": "Beats By Marc"},
    {"name": "Synthetic Waves", "artist": "Neon Glide"},
    {"name": "Acoustic Flow", "artist": "Luna Shade"},
    {"name": "Funky Town Groove", "artist": "The Bassline Crew"},
  ];

  @override
  void onClose() {
    final toDispose = captionController;
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        toDispose.dispose();
      } catch (_) {}
    });
    super.onClose();
  }

  String getStyleThumbnail(String style) {
    switch (style.toLowerCase()) {
      case 'shuffle':
        return "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&auto=format&fit=crop&q=80";
      case 'hip hop':
        return "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&auto=format&fit=crop&q=80";
      case 'popping':
        return "https://images.unsplash.com/photo-1547153760-18fc86324498?w=600&auto=format&fit=crop&q=80";
      case 'salsa':
        return "https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&auto=format&fit=crop&q=80";
      default:
        return "https://images.unsplash.com/photo-1508847154043-be12a62861c1?w=600&auto=format&fit=crop&q=80";
    }
  }

  Future<void> pickMedia(BuildContext context, String type) async {
    final ImagePicker picker = ImagePicker();
    if (type == "video") {
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        double duration = 15.0;
        try {
          final tempController = VideoPlayerController.file(File(video.path));
          await tempController.initialize();
          final videoDuration = tempController.value.duration.inMilliseconds / 1000.0;
          if (videoDuration > 0) {
            duration = videoDuration;
          }
          await tempController.dispose();
        } catch (e) {
          debugPrint("Error reading video duration: $e");
        }

        final newItem = SelectedMediaItem(
          id: "item_${DateTime.now().millisecondsSinceEpoch}_${video.name}",
          file: video,
          type: "video",
          duration: duration,
        );
        selectedMediaItems.add(newItem);

        // Auto navigate to Video Editor
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => VideoEditorScreen(item: newItem)));
      }
    } else {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final newItem = SelectedMediaItem(
          id: "item_${DateTime.now().millisecondsSinceEpoch}_${image.name}",
          file: image,
          type: "image",
        );
        selectedMediaItems.add(newItem);

        // Auto navigate to Image Editor
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => ImageEditorScreen(item: newItem)));
      }
    }
  }

  void submitPost(BuildContext context) async {
    if (captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(CreatePostStrings.writeCaptionError)));
      return;
    }

    if (selectedMediaItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(CreatePostStrings.selectMediaError)));
      return;
    }

    final authService = Get.find<AuthController>();
    final feedController = Get.find<FeedController>();
    final currentUser = authService.currentUserProfile;

    if (currentUser == null) return;

    final selectedMusicDetails = musicList.firstWhere(
      (m) => m["name"] == selectedMusic.value,
      orElse: () => {"name": "Original Audio", "artist": currentUser.displayName},
    );

    // Serialize media item parameters to a JSON string
    final List<Map<String, dynamic>> mediaListJson = selectedMediaItems.map((item) {
      final ratio = item.cropAspectRatio.value == "9:16" ? 9 / 16 : (item.cropAspectRatio.value == "1:1" ? 1.0 : 4 / 5);
      return {
        'url': item.file.path,
        'type': item.type,
        'cropAspectRatio': ratio,
        'filterType': item.selectedFilter.value,
        'brightness': item.brightness.value,
        'startTimeMs': (item.startTimeSec.value * 1000).toInt(),
        'endTimeMs': (item.endTimeSec.value * 1000).toInt(),
        'scale': item.scale.value,
        'panX': item.panX.value,
        'panY': item.panY.value,
        'rotation': item.rotation.value,
      };
    }).toList();

    final String serializedMedia = jsonEncode(mediaListJson);

    // Use parameters from the first selected item for overall post fallback metadata
    final firstItem = selectedMediaItems.first;
    final firstRatio = firstItem.cropAspectRatio.value == "9:16"
        ? 9 / 16
        : (firstItem.cropAspectRatio.value == "1:1" ? 1.0 : 4 / 5);

    feedController.addPostToQueue(
      caption: captionController.text.trim(),
      musicName: selectedMusicDetails["name"]!,
      musicArtist: selectedMusicDetails["artist"]!,
      danceStyle: selectedStyle.value,
      dancer: currentUser,
      videoPath: serializedMedia, // Pass JSON string in place of videoPath
      thumbnailPath: firstItem.file.path,
      cropAspectRatio: firstRatio,
      filterType: firstItem.selectedFilter.value,
      brightness: firstItem.brightness.value,
      startTimeMs: (firstItem.startTimeSec.value * 1000).toInt(),
      endTimeMs: (firstItem.endTimeSec.value * 1000).toInt(),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

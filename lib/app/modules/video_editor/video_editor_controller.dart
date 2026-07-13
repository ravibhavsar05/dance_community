import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:dance_pulse/app/modules/create_post/create_post_controller.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class VideoEditorController extends GetxController {
  final SelectedMediaItem item;
  VideoEditorController({required this.item});

  VideoPlayerController? videoPlayerController;
  final isInitialized = false.obs;
  final hasError = false.obs;
  final isSeeking = false.obs;

  late final RxString localRatio;
  late final RxString localFilter;
  late final RxDouble localBrightness;
  late final RxDouble localStart;
  late final RxDouble localEnd;
  late final RxDouble durationSec;
  late final RxInt localRotation;

  late final TransformationController transformationController;

  @override
  void onInit() {
    super.onInit();
    localRatio = item.cropAspectRatio.value.obs;
    localFilter = item.selectedFilter.value.obs;
    localBrightness = item.brightness.value.obs;
    localStart = item.startTimeSec.value.obs;
    localEnd = item.endTimeSec.value.obs;
    durationSec = item.videoDurationSec.value.obs;
    localRotation = item.rotation.value.obs;

    final initialRatio = item.cropAspectRatio.value;
    final width = initialRatio == "9:16" ? 180.0 : (initialRatio == "1:1" ? 240.0 : 220.0);
    final height = initialRatio == "9:16" ? 320.0 : (initialRatio == "1:1" ? 240.0 : 275.0);

    transformationController = TransformationController();
    final initialMatrix = Matrix4.identity()
      ..translateByVector3(v.Vector3(item.panX.value * width, item.panY.value * height, 0.0))
      ..scaleByVector3(v.Vector3(item.scale.value, item.scale.value, 1.0));
    transformationController.value = initialMatrix;

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      videoPlayerController = VideoPlayerController.file(File(item.file.path));
      await videoPlayerController!.initialize();
      videoPlayerController!.setLooping(false);
      videoPlayerController!.addListener(_videoListener);
      
      final dur = videoPlayerController!.value.duration.inMilliseconds / 1000.0;
      if (dur > 0 && durationSec.value == 15.0 && item.videoDurationSec.value == 15.0) {
        durationSec.value = dur;
        localEnd.value = dur;
      }
      
      await videoPlayerController!.seekTo(Duration(milliseconds: (localStart.value * 1000).toInt()));
      isInitialized.value = true;
      videoPlayerController!.play();
    } catch (e) {
      debugPrint("Error initializing editor video: $e");
      hasError.value = true;
    }
  }

  void _videoListener() {
    if (videoPlayerController == null || isSeeking.value) return;
    final posMs = videoPlayerController!.value.position.inMilliseconds;
    final startMs = (localStart.value * 1000).toInt();
    final endMs = (localEnd.value * 1000).toInt();

    if (endMs > startMs) {
      if (posMs >= endMs || posMs < startMs) {
        isSeeking.value = true;
        videoPlayerController!.seekTo(Duration(milliseconds: startMs)).then((_) {
          isSeeking.value = false;
        });
      }
    }
  }

  void togglePlayPause() {
    if (videoPlayerController == null || !isInitialized.value) return;
    if (videoPlayerController!.value.isPlaying) {
      videoPlayerController!.pause();
    } else {
      videoPlayerController!.play();
    }
    update();
  }

  void saveAndApply(BuildContext context) {
    item.cropAspectRatio.value = localRatio.value;
    item.selectedFilter.value = localFilter.value;
    item.brightness.value = localBrightness.value;
    item.startTimeSec.value = localStart.value;
    item.endTimeSec.value = localEnd.value;
    item.videoDurationSec.value = durationSec.value;
    item.rotation.value = localRotation.value;
    
    final matrix = transformationController.value;
    final translation = matrix.getTranslation();
    
    final ratio = localRatio.value;
    final width = ratio == "9:16" ? 180.0 : (ratio == "1:1" ? 240.0 : 220.0);
    final height = ratio == "9:16" ? 320.0 : (ratio == "1:1" ? 240.0 : 275.0);

    item.scale.value = matrix.getMaxScaleOnAxis();
    item.panX.value = translation.x / width;
    item.panY.value = translation.y / height;
    
    item.isCropped.value = true;
    
    Navigator.of(context).pop();
  }

  @override
  void onClose() {
    transformationController.dispose();
    videoPlayerController?.removeListener(_videoListener);
    videoPlayerController?.dispose();
    super.onClose();
  }
}

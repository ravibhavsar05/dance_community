import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:dance_pulse/app/modules/create_post/create_post_controller.dart';
import 'package:dance_pulse/app/modules/video_editor/video_editor_controller.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';

class VideoEditorScreen extends StatelessWidget {
  final SelectedMediaItem item;
  const VideoEditorScreen({super.key, required this.item});

  ColorFilter _getColorFilter(String filter) {
    switch (filter) {
      case 'warm':
        return const ColorFilter.matrix([
          1.2,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.8,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
        ]);
      case 'cool':
        return const ColorFilter.matrix([
          0.8,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.2,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
        ]);
      case 'vintage':
        return const ColorFilter.matrix([
          0.9,
          0.5,
          0.1,
          0.0,
          0.0,
          0.3,
          0.8,
          0.1,
          0.0,
          0.0,
          0.2,
          0.2,
          0.5,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
        ]);
      case 'monochrome':
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0.0,
          0.0,
          0.2126,
          0.7152,
          0.0722,
          0.0,
          0.0,
          0.2126,
          0.7152,
          0.0722,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
        ]);
      default:
        return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    }
  }

  ColorFilter _getBrightnessFilter(double brightness) {
    return ColorFilter.matrix([
      brightness,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      brightness,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      brightness,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(VideoEditorController(item: item), tag: item.id);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "EDIT VIDEO",
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
            onPressed: () {
              controller.localRotation.value = (controller.localRotation.value + 1) % 4;
            },
          ),
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.accent),
            onPressed: () => controller.saveAndApply(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video Preview Area
            Obx(() {
              double previewHeight;
              double previewWidth;
              if (controller.localRatio.value == "9:16") {
                previewHeight = 320.0;
                previewWidth = 180.0;
              } else if (controller.localRatio.value == "1:1") {
                previewHeight = 240.0;
                previewWidth = 240.0;
              } else {
                // "4:5"
                previewHeight = 275.0;
                previewWidth = 220.0;
              }

              return Container(
                height: 360,
                color: Colors.black,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (controller.isInitialized.value && controller.videoPlayerController != null)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: previewHeight,
                        width: previewWidth,
                        child: ClipRect(
                          child: InteractiveViewer(
                            transformationController: controller.transformationController,
                            minScale: 1.0,
                            maxScale: 5.0,
                            child: ColorFiltered(
                              colorFilter: _getColorFilter(controller.localFilter.value),
                              child: ColorFiltered(
                                colorFilter: _getBrightnessFilter(controller.localBrightness.value),
                                child: RotatedBox(
                                  quarterTurns: controller.localRotation.value,
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    clipBehavior: Clip.hardEdge,
                                    child: SizedBox(
                                      width: controller.videoPlayerController!.value.size.width > 0
                                          ? controller.videoPlayerController!.value.size.width
                                          : 1080,
                                      height: controller.videoPlayerController!.value.size.height > 0
                                          ? controller.videoPlayerController!.value.size.height
                                          : 1920,
                                      child: VideoPlayer(controller.videoPlayerController!),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (controller.hasError.value)
                      const Icon(Icons.error_outline, size: 64, color: Colors.white24)
                    else
                      const CircularProgressIndicator(color: AppTheme.primary),

                    // Grid lines overlay
                    IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: previewHeight,
                        width: previewWidth,
                        decoration: BoxDecoration(border: Border.all(color: Colors.white54, width: 1.5)),
                        child: Stack(
                          children: [
                            Positioned(
                              top: previewHeight / 3,
                              left: 0,
                              right: 0,
                              child: Container(height: 0.8, color: Colors.white38),
                            ),
                            Positioned(
                              top: (previewHeight / 3) * 2,
                              left: 0,
                              right: 0,
                              child: Container(height: 0.8, color: Colors.white38),
                            ),
                            Positioned(
                              left: previewWidth / 3,
                              top: 0,
                              bottom: 0,
                              child: Container(width: 0.8, color: Colors.white38),
                            ),
                            Positioned(
                              left: (previewWidth / 3) * 2,
                              top: 0,
                              bottom: 0,
                              child: Container(width: 0.8, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Play/Pause button
                  Obx(() {
                    if (controller.isInitialized.value && controller.videoPlayerController != null) {
                      return Center(
                        child: ElevatedButton.icon(
                          onPressed: controller.togglePlayPause,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white10,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: Icon(
                            controller.videoPlayerController!.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            controller.videoPlayerController!.value.isPlaying ? "Pause" : "Play",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(height: 20),

                  // Aspect Ratio Options
                  const Text(
                    "Aspect Ratio",
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Obx(
                    () => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ["9:16", "1:1", "4:5"].map((ratio) {
                        final isSelected = controller.localRatio.value == ratio;
                        return ChoiceChip(
                          label: Text(ratio),
                          selected: isSelected,
                          selectedColor: AppTheme.primary,
                          backgroundColor: AppTheme.cardBg,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) controller.localRatio.value = ratio;
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Video Trim controls
                  const Text(
                    "Trim Video",
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Obx(
                    () => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Start: ${controller.localStart.value.toStringAsFixed(1)}s",
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              Text(
                                "End: ${controller.localEnd.value.toStringAsFixed(1)}s",
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                          RangeSlider(
                            values: RangeValues(controller.localStart.value, controller.localEnd.value),
                            min: 0.0,
                            max: controller.durationSec.value,
                            divisions: (controller.durationSec.value * 10).toInt() > 0
                                ? (controller.durationSec.value * 10).toInt()
                                : 10,
                            labels: RangeLabels(
                              "${controller.localStart.value.toStringAsFixed(1)}s",
                              "${controller.localEnd.value.toStringAsFixed(1)}s",
                            ),
                            activeColor: AppTheme.primary,
                            inactiveColor: AppTheme.border,
                            onChanged: (RangeValues values) {
                              controller.localStart.value = values.start;
                              controller.localEnd.value = values.end;
                            },
                          ),
                          Text(
                            "Duration: ${(controller.localEnd.value - controller.localStart.value).toStringAsFixed(1)}s",
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Filter Choice Chips
                  const Text(
                    "Apply Filter",
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Obx(
                    () => SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ["none", "warm", "cool", "vintage", "monochrome"].map((filter) {
                          final isSelected = controller.localFilter.value == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(filter.capitalizeFirst!),
                              selected: isSelected,
                              selectedColor: AppTheme.primary,
                              backgroundColor: AppTheme.cardBg,
                              labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textSecondary),
                              onSelected: (val) {
                                if (val) controller.localFilter.value = filter;
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Brightness Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Adjust Brightness",
                        style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Obx(
                        () => Text(
                          "${(controller.localBrightness.value * 100 - 100).toInt()}%",
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  Obx(
                    () => Slider(
                      value: controller.localBrightness.value,
                      min: 0.5,
                      max: 1.5,
                      divisions: 20,
                      activeColor: AppTheme.accent,
                      inactiveColor: AppTheme.border,
                      onChanged: (val) {
                        controller.localBrightness.value = val;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

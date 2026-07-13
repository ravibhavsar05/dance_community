import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/create_post_controller.dart';
import '../theme/app_theme.dart';
import 'app_strings.dart';
import 'video_editor_screen.dart';
import 'image_editor_screen.dart';
import 'instagram_media_picker_screen.dart';
import '../widgets/mention_autocomplete_wrapper.dart';

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

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
    final controller = Get.put(CreatePostController());

    return Scaffold(
      appBar: AppBar(
        title: const Text(CreatePostStrings.createPostHeader),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Styled Media Action Cards
            GestureDetector(
              onTap: () {
                InstagramMediaPickerScreen.show(context, isFromCreatePost: true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      "Manage & Select Media (Instagram Picker)",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Selected Content horizontal list view
            const Text(
              "Selected Content",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            Obx(() {
              if (controller.selectedMediaItems.isEmpty) {
                return GestureDetector(
                  onTap: () {
                    InstagramMediaPickerScreen.show(context, isFromCreatePost: true);
                  },
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.perm_media_outlined, size: 36, color: AppTheme.textSecondary),
                        SizedBox(height: 10),
                        Text(
                          "No media selected yet",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Tap to select videos or photos using the Picker",
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: controller.selectedMediaItems.length,
                  itemBuilder: (context, index) {
                    final item = controller.selectedMediaItems[index];
                    final isVideo = item.type == "video";

                    return Padding(
                      padding: const EdgeInsets.only(right: 14.0),
                      child: GestureDetector(
                        onTap: () {
                          if (isVideo) {
                            Navigator.of(
                              context,
                            ).push(MaterialPageRoute(builder: (context) => VideoEditorScreen(item: item)));
                          } else {
                            Navigator.of(
                              context,
                            ).push(MaterialPageRoute(builder: (context) => ImageEditorScreen(item: item)));
                          }
                        },
                        child: Container(
                          width: 110,
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border, width: 1.5),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Obx(() {
                                    final double s = item.scale.value;
                                    final double pxOffset = item.panX.value;
                                    final double pyOffset = item.panY.value;
                                    final String filter = item.selectedFilter.value;
                                    final double brightness = item.brightness.value;
                                    final String ratioStr = item.cropAspectRatio.value;

                                    final double cropRatio = ratioStr == "9:16"
                                        ? 9 / 16
                                        : (ratioStr == "1:1" ? 1.0 : 4 / 5);

                                    return ColorFiltered(
                                      colorFilter: _getColorFilter(filter),
                                      child: ColorFiltered(
                                        colorFilter: _getBrightnessFilter(brightness),
                                        child: Center(
                                          child: AspectRatio(
                                            aspectRatio: cropRatio,
                                            child: ClipRect(
                                              child: LayoutBuilder(
                                                builder: (context, constraints) {
                                                  final double px = pxOffset * constraints.maxWidth;
                                                  final double py = pyOffset * constraints.maxHeight;

                                                  return Transform(
                                                    transform: Matrix4.identity()
                                                      ..translate(px, py)
                                                      ..scale(s),
                                                    child: RotatedBox(
                                                      quarterTurns: item.rotation.value,
                                                      child: !isVideo
                                                          ? Image.file(
                                                              File(item.file.path),
                                                              fit: BoxFit.cover,
                                                              width: constraints.maxWidth,
                                                              height: constraints.maxHeight,
                                                            )
                                                          : Image.network(
                                                              controller.getStyleThumbnail(
                                                                controller.selectedStyle.value,
                                                              ),
                                                              fit: BoxFit.cover,
                                                              width: constraints.maxWidth,
                                                              height: constraints.maxHeight,
                                                            ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),

                              // Dark tint layer
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.black.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),

                              // Play icon for video overlay
                              if (isVideo)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                  ),
                                ),

                              // Edit label
                              Positioned(
                                bottom: 6,
                                left: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.edit, color: Colors.white70, size: 10),
                                      const SizedBox(width: 4),
                                      Text(
                                        isVideo ? "Edit" : "Crop",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Delete badge icon top-right
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    controller.selectedMediaItems.removeAt(index);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),

                              // Page index number badge top-left
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isVideo ? AppTheme.primary : AppTheme.accent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${index + 1}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 24),

            // Caption Input
            const Text(
              CreatePostStrings.captionTitle,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            MentionAutocompleteWrapper(
              controller: controller.captionController,
              child: TextField(
                controller: controller.captionController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(hintText: CreatePostStrings.captionHint),
              ),
            ),
            const SizedBox(height: 20),

            // Select Music Track
            const Text(
              "Select Beat / Music",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: Obx(
                  () => DropdownButton<String>(
                    value: controller.selectedMusic.value,
                    isExpanded: true,
                    dropdownColor: AppTheme.cardBg,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        controller.selectedMusic.value = newValue;
                      }
                    },
                    items: controller.musicList.map<DropdownMenuItem<String>>((Map<String, String> music) {
                      return DropdownMenuItem<String>(
                        value: music["name"],
                        child: Row(
                          children: [
                            const Icon(Icons.music_note_rounded, size: 18, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text("${music["name"]} - ${music["artist"]}"),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Select Dance Style
            const Text(
              CreatePostStrings.selectCategory,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: Obx(
                  () => DropdownButton<String>(
                    value: controller.selectedStyle.value,
                    isExpanded: true,
                    dropdownColor: AppTheme.cardBg,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        controller.selectedStyle.value = newValue;
                      }
                    },
                    items: controller.danceStyles.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            const Icon(Icons.accessibility_new_rounded, size: 18, color: AppTheme.accent),
                            const SizedBox(width: 8),
                            Text(value),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),

            // Share / Post Button
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => controller.submitPost(context),
                child: const Text(
                  CreatePostStrings.shareWithCommunity,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

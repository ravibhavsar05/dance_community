import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:insta_assets_picker/insta_assets_picker.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import '../../controllers/create_post_controller.dart';
import '../theme/app_theme.dart';
import 'create_post_screen.dart';

class InstagramMediaPickerScreen {
  static Future<void> show(BuildContext context, {required bool isFromCreatePost}) async {
    final navigator = Navigator.of(context);
    try {
      bool dialogShown = false;

      final bool isLight = Theme.of(context).brightness == Brightness.light;
      final ThemeData pickerTheme = InstaAssetPicker.themeData(AppTheme.primary, light: isLight);

      await InstaAssetPicker.pickAssets(
        context,
        maxAssets: 9,
        pickerConfig: InstaAssetPickerConfig(title: 'Select Media', pickerTheme: pickerTheme),
        onCompleted: (Stream<InstaAssetsExportDetails> exportDetailsStream) {
          exportDetailsStream.listen(
            (details) async {
              if (details.progress < 1.0 && !dialogShown) {
                dialogShown = true;
                Get.dialog(
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border, width: 1.5),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary)),
                          SizedBox(height: 16),
                          Text(
                            "Processing media...",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  barrierDismissible: false,
                );
              }

              if (details.progress == 1.0) {
                final List<SelectedMediaItem> selectedItems = [];

                for (var data in details.data) {
                  final entity = data.selectedData.asset;
                  final File? file = data.croppedFile ?? await entity.file;

                  if (file != null) {
                    final String type = entity.type == AssetType.video ? "video" : "image";
                    double duration = 15.0;
                    if (type == "video") {
                      duration = entity.duration.toDouble();
                    }

                    final item = SelectedMediaItem(
                      id: entity.id,
                      file: XFile(file.path),
                      type: type,
                      duration: duration,
                    );

                    // Set crop aspect ratio based on details.aspectRatio
                    if (details.aspectRatio == 1.0) {
                      item.cropAspectRatio.value = "1:1";
                    } else if (details.aspectRatio == 4 / 5 || details.aspectRatio == 0.8) {
                      item.cropAspectRatio.value = "4:5";
                    } else {
                      item.cropAspectRatio.value = "9:16";
                    }

                    if (entity.width > 0 && entity.height > 0) {
                      item.originalAspectRatio.value = entity.width / entity.height;
                    }

                    selectedItems.add(item);
                  }
                }

                // Dismiss processing dialog if shown
                if (dialogShown && (Get.isDialogOpen ?? false)) {
                  Get.back();
                }

                // Update controller
                final postController = Get.isRegistered<CreatePostController>()
                    ? Get.find<CreatePostController>()
                    : Get.put(CreatePostController());

                postController.selectedMediaItems.assignAll(selectedItems);

                if (!isFromCreatePost && selectedItems.isNotEmpty) {
                  // Navigate to CreatePostScreen
                  navigator.push(MaterialPageRoute(builder: (context) => const CreatePostScreen()));
                }
              }
            },
            onError: (error) {
              if (dialogShown && (Get.isDialogOpen ?? false)) {
                Get.back();
              }
              Get.snackbar("Export Error", "Failed to export assets: $error");
            },
          );
        },
      );
    } catch (e) {
      Get.snackbar("Picker Error", "Could not launch picker: $e");
    }
  }
}

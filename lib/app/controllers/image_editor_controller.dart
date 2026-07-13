import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'create_post_controller.dart';

class ImageEditorController extends GetxController {
  final SelectedMediaItem item;
  ImageEditorController({required this.item});

  late final RxString localRatio;
  late final RxString localFilter;
  late final RxDouble localBrightness;
  late final RxInt localRotation;

  late final TransformationController transformationController;

  @override
  void onInit() {
    super.onInit();
    localRatio = item.cropAspectRatio.value.obs;
    localFilter = item.selectedFilter.value.obs;
    localBrightness = item.brightness.value.obs;
    localRotation = item.rotation.value.obs;

    final initialRatio = item.cropAspectRatio.value;
    final width = initialRatio == "9:16" ? 180.0 : (initialRatio == "1:1" ? 240.0 : 220.0);
    final height = initialRatio == "9:16" ? 320.0 : (initialRatio == "1:1" ? 240.0 : 275.0);

    transformationController = TransformationController();
    final initialMatrix = Matrix4.identity()
      ..translate(item.panX.value * width, item.panY.value * height)
      ..scale(item.scale.value);
    transformationController.value = initialMatrix;
  }

  void saveAndApply(BuildContext context) {
    item.cropAspectRatio.value = localRatio.value;
    item.selectedFilter.value = localFilter.value;
    item.brightness.value = localBrightness.value;
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
    super.onClose();
  }
}

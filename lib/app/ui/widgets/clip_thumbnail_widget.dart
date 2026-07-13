import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../data/models/dance_models.dart';
import '../../data/services/supabase_store.dart';

class ClipThumbnailWidget extends StatelessWidget {
  final DanceClip clip;
  final double borderRadius;
  final BoxFit fit;

  const ClipThumbnailWidget({super.key, required this.clip, this.borderRadius = 8.0, this.fit = BoxFit.cover});

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
    final firstItem = clip.mediaItems.isNotEmpty ? clip.mediaItems.first : null;
    final String filter = firstItem?['filterType'] ?? clip.filterType;
    final double brightness = (firstItem?['brightness'] as num?)?.toDouble() ?? clip.brightness;
    final int rotation = (firstItem?['rotation'] as num?)?.toInt() ?? 0;
    final double scale = (firstItem?['scale'] as num?)?.toDouble() ?? 1.0;
    final double panX = (firstItem?['panX'] as num?)?.toDouble() ?? 0.0;
    final double panY = (firstItem?['panY'] as num?)?.toDouble() ?? 0.0;
    final double ar = (firstItem?['cropAspectRatio'] as num?)?.toDouble() ?? clip.cropAspectRatio;
    final String url = clip.thumbnailUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: ar,
        child: ColorFiltered(
          colorFilter: _getColorFilter(filter),
          child: ColorFiltered(
            colorFilter: _getBrightnessFilter(brightness),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double px = panX * constraints.maxWidth;
                final double py = panY * constraints.maxHeight;

                return Transform(
                  transform: Matrix4.translationValues(px, py, 0.0)
                    ..scaleByDouble(scale, scale, 1.0, 1.0),
                  child: RotatedBox(
                    quarterTurns: rotation,
                    child: url.startsWith('http://') || url.startsWith('https://')
                        ? CachedNetworkImage(
                            imageUrl: SupabaseStore.getSizedImageUrl(url, 'medium'),
                            httpHeaders: SupabaseStore.getHeadersForUrl(url) ?? const {},
                            fit: fit,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[900],
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(Icons.image_not_supported_rounded, size: 24, color: Colors.white24),
                            ),
                          )
                        : Image.file(
                            File(url),
                            fit: fit,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.image_not_supported_rounded, size: 24, color: Colors.white24),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:dance_pulse/app/data/models/dance_models.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';
import 'package:dance_pulse/app/modules/home_feed/feed_controller.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';
import 'package:dance_pulse/app/modules/home_feed/widgets/pinch_zoom_wrapper.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class CarouselMediaWidget extends StatefulWidget {
  final DanceClip clip;
  final bool isActive;

  const CarouselMediaWidget({super.key, required this.clip, required this.isActive});

  @override
  State<CarouselMediaWidget> createState() => _CarouselMediaWidgetState();
}

class _CarouselMediaWidgetState extends State<CarouselMediaWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Map<int, bool> _isInitialized = {};
  final Map<int, bool> _hasError = {};
  final Map<int, bool> _isSeekingRange = {};
  Worker? _muteWorker;

  List<Map<String, dynamic>> get _items => widget.clip.mediaItems;

  double _aspectRatioForIndex(int index) {
    if (index < 0 || index >= _items.length) return widget.clip.cropAspectRatio;
    final ar = (_items[index]['cropAspectRatio'] as num?)?.toDouble();
    if (ar != null && ar > 0) return ar;
    // Fallback from first item or clip-level
    return widget.clip.cropAspectRatio;
  }

  double get _currentAspectRatio => _aspectRatioForIndex(_currentPage);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeControllerForPage(0);

    final feedController = Get.find<FeedController>();
    _muteWorker = ever(feedController.isMuted, (bool muted) {
      _videoControllers.forEach((page, controller) {
        if (_isInitialized[page] == true) {
          controller.setVolume(muted ? 0.0 : 1.0);
        }
      });
    });
  }

  @override
  void didUpdateWidget(CarouselMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _handleFocusChange(widget.isActive);
    }
  }

  void _handleFocusChange(bool focus) {
    final currentController = _videoControllers[_currentPage];
    if (currentController != null && _isInitialized[_currentPage] == true) {
      if (focus) {
        currentController.play();
      } else {
        currentController.pause();
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _initializeControllerForPage(int page) async {
    if (page < 0 || page >= _items.length) return;
    final item = _items[page];
    if (item['type'] != 'video') return;
    if (_videoControllers.containsKey(page)) return;

    final String videoUrl = item['url'] ?? '';
    if (videoUrl.isEmpty) return;

    VideoPlayerController controller;
    try {
      if (videoUrl.startsWith('http://') || videoUrl.startsWith('https://')) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          httpHeaders: SupabaseStore.getHeadersForUrl(videoUrl) ?? const {},
        );
      } else {
        controller = VideoPlayerController.file(File(videoUrl));
      }
      _videoControllers[page] = controller;

      final feedController = Get.find<FeedController>();
      await controller.initialize();
      await controller.setVolume(feedController.isMuted.value ? 0.0 : 1.0);

      // Extract duration boundaries
      int start = 0;
      int end = 0;
      if (item['startTimeMs'] != null) {
        start = (item['startTimeMs'] as num).toInt();
      }
      if (item['endTimeMs'] != null) {
        end = (item['endTimeMs'] as num).toInt();
      }

      if (end > start) {
        controller.setLooping(false);
        controller.addListener(() {
          _videoListener(page, controller, start, end);
        });
        await controller.seekTo(Duration(milliseconds: start));
      } else {
        controller.setLooping(true);
      }

      if (mounted) {
        setState(() {
          _isInitialized[page] = true;
        });
      }

      if (widget.isActive && _currentPage == page) {
        controller.play();
      }
    } catch (e) {
      debugPrint("Carousel video init failed for page $page: $e");
      if (mounted) {
        setState(() {
          _hasError[page] = true;
        });
      }
    }
  }

  void _videoListener(int page, VideoPlayerController controller, int start, int end) {
    if (_isSeekingRange[page] == true) return;
    final position = controller.value.position.inMilliseconds;
    if (position >= end || position < start) {
      _isSeekingRange[page] = true;
      controller.seekTo(Duration(milliseconds: start)).then((_) {
        _isSeekingRange[page] = false;
      });
    }
  }

  void _onPageChanged(int index) {
    // Pause previous video controller
    final oldController = _videoControllers[_currentPage];
    if (oldController != null && _isInitialized[_currentPage] == true) {
      oldController.pause();
    }

    if (mounted) {
      setState(() {
        _currentPage = index;
      });
    }

    // Initialize & play new page controller
    final newItem = _items[index];
    if (newItem['type'] == 'video') {
      if (_videoControllers.containsKey(index)) {
        final newController = _videoControllers[index];
        if (newController != null && _isInitialized[index] == true && widget.isActive) {
          newController.play();
        }
      } else {
        _initializeControllerForPage(index);
      }
    }
  }

  void _togglePlayPause() {
    final controller = _videoControllers[_currentPage];
    if (controller == null || _isInitialized[_currentPage] != true) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    if (mounted) setState(() {});
  }

  // ── Shimmer placeholder while image loads ──────────────────────────────────
  Widget _shimmerPlaceholder(double w, double h) {
    return SizedBox(width: w, height: h, child: _ShimmerLoader());
  }

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
  void dispose() {
    _muteWorker?.dispose();
    _videoControllers.forEach((page, controller) {
      controller.dispose();
    });
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedController = Get.find<FeedController>();
    // Compute the current slide's aspect ratio for animated height
    final double currentAR = _currentAspectRatio;
    // Screen width drives the animated height so layout doesn't jump abruptly
    final double screenW = MediaQuery.of(context).size.width;
    final double targetHeight = screenW / currentAR;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: screenW,
      height: targetHeight,
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // PageView for carousel content
          PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final item = _items[index];
              final isVideo = item['type'] == 'video';
              final filter = item['filterType'] ?? 'none';
              final brightness = (item['brightness'] as num?)?.toDouble() ?? 1.0;
              final url = item['url'] ?? '';
              final double itemAR =
                  (_items[index]['cropAspectRatio'] as num?)?.toDouble() ?? widget.clip.cropAspectRatio;
              final rot = (item['rotation'] as num?)?.toInt() ?? 0;

              if (!isVideo) {
                return GestureDetector(
                  onTap: _togglePlayPause,
                  child: Center(
                    child: PinchZoomWrapper(
                      child: ClipRect(
                        child: AspectRatio(
                          aspectRatio: itemAR,
                          child: ColorFiltered(
                            colorFilter: _getColorFilter(filter),
                            child: ColorFiltered(
                              colorFilter: _getBrightnessFilter(brightness),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final double s = (item['scale'] as num?)?.toDouble() ?? 1.0;
                                  final double px = ((item['panX'] as num?)?.toDouble() ?? 0.0) * constraints.maxWidth;
                                  final double py = ((item['panY'] as num?)?.toDouble() ?? 0.0) * constraints.maxHeight;

                                  return Transform(
                                    transform: Matrix4.identity()
                                      ..translateByVector3(v.Vector3(px, py, 0.0))
                                      ..scaleByVector3(v.Vector3(s, s, 1.0)),
                                    child: RotatedBox(
                                      quarterTurns: rot,
                                      child: (url.startsWith('http://') || url.startsWith('https://')
                                          ? CachedNetworkImage(
                                              imageUrl: SupabaseStore.getSizedImageUrl(url, 'large'),
                                              httpHeaders: SupabaseStore.getHeadersForUrl(url) ?? const {},
                                              fit: BoxFit.cover,
                                              width: constraints.maxWidth,
                                              height: constraints.maxHeight,
                                              placeholder: (context, url) =>
                                                  _shimmerPlaceholder(constraints.maxWidth, constraints.maxHeight),
                                              errorWidget: (context, url, error) => const Center(
                                                child: Icon(
                                                  Icons.image_not_supported_rounded,
                                                  size: 48,
                                                  color: Colors.white24,
                                                ),
                                              ),
                                            )
                                          : Image.file(
                                              File(url),
                                              fit: BoxFit.cover,
                                              width: constraints.maxWidth,
                                              height: constraints.maxHeight,
                                              errorBuilder: (context, error, stackTrace) => const Center(
                                                child: Icon(
                                                  Icons.image_not_supported_rounded,
                                                  size: 48,
                                                  color: Colors.white24,
                                                ),
                                              ),
                                            )),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                // Video item rendering
                final controller = _videoControllers[index];
                final isInit = _isInitialized[index] == true;
                final hasErr = _hasError[index] == true;

                return GestureDetector(
                  onTap: _togglePlayPause,
                  child: Center(
                    child: ClipRect(
                      child: AspectRatio(
                        aspectRatio: itemAR,
                        child: ColorFiltered(
                          colorFilter: _getColorFilter(filter),
                          child: ColorFiltered(
                            colorFilter: _getBrightnessFilter(brightness),
                            child: Container(
                              color: Colors.black,
                              child: isInit && controller != null
                                  ? LayoutBuilder(
                                      builder: (context, constraints) {
                                        final double s = (item['scale'] as num?)?.toDouble() ?? 1.0;
                                        final double px =
                                            ((item['panX'] as num?)?.toDouble() ?? 0.0) * constraints.maxWidth;
                                        final double py =
                                            ((item['panY'] as num?)?.toDouble() ?? 0.0) * constraints.maxHeight;

                                        return Transform(
                                          transform: Matrix4.identity()
                                            ..translateByVector3(v.Vector3(px, py, 0.0))
                                            ..scaleByVector3(v.Vector3(s, s, 1.0)),
                                          child: RotatedBox(
                                            quarterTurns: rot,
                                            child: SizedBox(
                                              width: constraints.maxWidth,
                                              height: constraints.maxHeight,
                                              child: FittedBox(
                                                fit: BoxFit.cover,
                                                clipBehavior: Clip.hardEdge,
                                                child: SizedBox(
                                                  width: controller.value.size.width > 0
                                                      ? controller.value.size.width
                                                      : 1080,
                                                  height: controller.value.size.height > 0
                                                      ? controller.value.size.height
                                                      : 1920,
                                                  child: VideoPlayer(controller),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : hasErr
                                  ? const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.video_library, size: 48, color: Colors.white24),
                                          SizedBox(height: 12),
                                          Text("Video failed to load", style: TextStyle(color: Colors.white30)),
                                        ],
                                      ),
                                    )
                                  : const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            },
          ),

          // Play/Pause Overlay indicator
          Builder(
            builder: (context) {
              final activeController = _videoControllers[_currentPage];
              final isInit = _isInitialized[_currentPage] == true;
              final isVideo = _items[_currentPage]['type'] == 'video';
              final isPlaying = activeController?.value.isPlaying ?? false;

              if (isVideo && isInit && !isPlaying) {
                return IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Mute/Unmute Overlay button on bottom right
          Builder(
            builder: (context) {
              final isVideo = _items[_currentPage]['type'] == 'video';
              if (!isVideo) return const SizedBox.shrink();
              return Positioned(
                bottom: 12,
                right: 12,
                child: Obx(() {
                  return GestureDetector(
                    onTap: () {
                      feedController.toggleMute();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: Icon(
                        feedController.isMuted.value ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  );
                }),
              );
            },
          ),

          // Carousel dots indicator overlay at bottom center
          if (_items.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_items.length, (index) {
                  final isCurrent = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isCurrent ? 8 : 6,
                    height: isCurrent ? 8 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrent ? AppTheme.primary : Colors.white54,
                    ),
                  );
                }),
              ),
            ),

          // Video Seekbar (progress indicator) for current page if it is video
          Builder(
            builder: (context) {
              final isVideo = _items[_currentPage]['type'] == 'video';
              final controller = _videoControllers[_currentPage];
              final isInit = _isInitialized[_currentPage] == true;

              if (isVideo && isInit && controller != null) {
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      colors: const VideoProgressColors(
                        playedColor: AppTheme.primary,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

/// Animated shimmer placeholder displayed while a network image loads.
class _ShimmerLoader extends StatefulWidget {
  const _ShimmerLoader();

  @override
  State<_ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<_ShimmerLoader> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                Color(0xFF1E1E1E),
                Color(0xFF2C2C2C),
                Color(0xFF383838),
                Color(0xFF2C2C2C),
                Color(0xFF1E1E1E),
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
          child: Center(child: Icon(Icons.image_rounded, size: 36, color: Colors.white12)),
        );
      },
    );
  }
}

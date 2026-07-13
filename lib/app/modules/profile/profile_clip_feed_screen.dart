import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dance_pulse/app/data/models/dance_models.dart';
import 'package:dance_pulse/app/modules/home_feed/feed_controller.dart';
import 'package:dance_pulse/app/modules/home_feed/home_feed_screen.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';

class ProfileClipFeedScreen extends StatefulWidget {
  final List<DanceClip> clips;
  final int initialIndex;

  const ProfileClipFeedScreen({super.key, required this.clips, required this.initialIndex});

  @override
  State<ProfileClipFeedScreen> createState() => _ProfileClipFeedScreenState();
}

class _ProfileClipFeedScreenState extends State<ProfileClipFeedScreen> {
  late ScrollController _scrollController;
  late int _focusedIndex;
  List<double> _accumulatedHeights = [];

  @override
  void initState() {
    super.initState();
    _focusedIndex = widget.initialIndex;

    // Precalculate item heights to avoid expensive O(N) layouts on every scroll event
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final double screenWidth = view.physicalSize.width / view.devicePixelRatio;

    double runningOffset = 0.0;
    _accumulatedHeights = List.generate(widget.clips.length, (index) {
      final clip = widget.clips[index];
      final firstItem = clip.mediaItems.isNotEmpty ? clip.mediaItems.first : null;
      final double ar = (firstItem?['cropAspectRatio'] as num?)?.toDouble() ?? clip.cropAspectRatio;
      final double mediaHeight = screenWidth / ar;
      // Header, footer, action bars, margin/padding is approx 185px
      final double itemHeight = mediaHeight + 185.0;
      runningOffset += itemHeight;
      return runningOffset;
    });

    double initialOffset = 0.0;
    if (widget.initialIndex > 0 && widget.initialIndex - 1 < _accumulatedHeights.length) {
      initialOffset = _accumulatedHeights[widget.initialIndex - 1];
    }

    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // O(log N) Binary Search to quickly find which card is active
  int _binarySearchForIndex(double viewportCenter) {
    int low = 0;
    int high = _accumulatedHeights.length - 1;

    while (low <= high) {
      int mid = (low + high) >> 1;
      double val = _accumulatedHeights[mid];

      if (viewportCenter < val) {
        if (mid == 0 || viewportCenter >= _accumulatedHeights[mid - 1]) {
          return mid;
        }
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return _accumulatedHeights.length - 1;
  }

  void _onScroll() {
    if (!mounted) return;
    if (widget.clips.isEmpty || _accumulatedHeights.isEmpty) return;

    final double scrollOffset = _scrollController.offset;
    final double viewportHeight = MediaQuery.of(context).size.height;

    // Find the item closest to the middle of the viewport
    final double viewportCenter = scrollOffset + (viewportHeight / 2) - 80;

    final int centerIndex = _binarySearchForIndex(viewportCenter);
    final clampedIndex = centerIndex.clamp(0, widget.clips.length - 1);

    if (_focusedIndex != clampedIndex) {
      setState(() {
        _focusedIndex = clampedIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Post',
          style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: GetBuilder<FeedController>(
        builder: (feedController) {
          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.cardBg,
            onRefresh: () async {
              await feedController.refreshData();
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              itemCount: widget.clips.length,
              itemBuilder: (context, index) {
                final originalClipIndex = feedController.clips.indexWhere((c) => c.id == widget.clips[index].id);
                final displayClip = originalClipIndex != -1
                    ? feedController.clips[originalClipIndex]
                    : widget.clips[index];

                return VideoFeedItem(
                  clip: displayClip,
                  isActive: index == _focusedIndex,
                  onDeleteSuccess: () {
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

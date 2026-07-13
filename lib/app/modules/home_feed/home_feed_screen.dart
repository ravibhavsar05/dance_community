import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebasecrashreport/app/data/models/dance_models.dart';
import 'package:firebasecrashreport/app/controllers/auth_controller.dart';
import 'package:firebasecrashreport/app/modules/home_feed/feed_controller.dart';
import 'package:firebasecrashreport/app/modules/home_feed/video_feed_item_controller.dart';
import 'package:firebasecrashreport/app/data/services/supabase_store.dart';
import 'package:firebasecrashreport/app/ui/theme/app_theme.dart';
import 'package:firebasecrashreport/app/utils/app_strings.dart';
import 'package:firebasecrashreport/app/modules/profile/profile_screen.dart';
import 'package:firebasecrashreport/app/modules/home_feed/widgets/carousel_media_widget.dart';
import 'package:firebasecrashreport/app/ui/widgets/mention_autocomplete_wrapper.dart';
import 'package:firebasecrashreport/app/modules/home_feed/widgets/mention_text.dart';
import 'package:firebasecrashreport/app/modules/live_stream/live_stream_controller.dart';
import 'package:firebasecrashreport/app/modules/live_stream/live_viewer_screen.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final feedController = Get.find<FeedController>();
    final followedClips = feedController.followedClips;
    if (followedClips.isEmpty) return;

    final double scrollOffset = _scrollController.offset;
    final double viewportHeight = MediaQuery.of(context).size.height;

    // Find which post card is closest to the middle of the viewport.
    // Approximate card height is around 560px.
    final double viewportCenter = scrollOffset + (viewportHeight / 2) - 80;
    const double estimatedCardHeight = 560.0;

    int centerIndex = (viewportCenter / estimatedCardHeight).floor();
    centerIndex = centerIndex.clamp(0, followedClips.length - 1);

    if (feedController.focusedIndex.value != centerIndex) {
      feedController.focusedIndex.value = centerIndex;
    }
  }

  Widget _buildLiveStreamsBar(BuildContext context) {
    final liveController = Get.find<LiveStreamController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Obx(() {
      final streams = liveController.activeLiveStreams;

      if (streams.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        height: 115,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: streams.length,
          itemBuilder: (context, index) {
            final session = streams[index];
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () => Get.to(() => LiveViewerScreen(session: session)),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        // Live Pulse ring
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [Colors.red, Colors.orange, Colors.red],
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.surface,
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundImage: NetworkImage(
                                session.hostAvatar,
                                headers: SupabaseStore.getHeadersForUrl(session.hostAvatar),
                              ),
                            ),
                          ),
                        ),
                        // Live Tag Overlay
                        Positioned(
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1),
                            ),
                            child: const Text(
                              "LIVE",
                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 70,
                      child: Text(
                        session.hostName,
                        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildEmptyFeedState(BuildContext context, Color textColor, Color textSecondary, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              "No posts from dancers you follow yet.",
              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Explore the Discover tab to find and follow your favorite dancers!",
              style: TextStyle(color: textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedController = Get.find<FeedController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        title: ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            'Dance Pulse',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white, fontFamily: 'Outfit'),
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Live Streams Bar (always shown at top when streams are active)
          _buildLiveStreamsBar(context),

          // Main video feed
          Expanded(
            child: Obx(() {
              final followedClips = feedController.followedClips;
              final liveController = Get.find<LiveStreamController>();

              if (feedController.isLoading && followedClips.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }

              if (followedClips.isEmpty) {
                // Show live streams section prominently when feed is empty
                return Column(
                  children: [
                    Obx(() {
                      final streams = liveController.activeLiveStreams;
                      if (streams.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                            child: Text(
                              "Live Now 🔴",
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 160,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: streams.length,
                              itemBuilder: (context, index) {
                                final session = streams[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: GestureDetector(
                                    onTap: () => Get.to(() => LiveViewerScreen(session: session)),
                                    child: Container(
                                      width: 140,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: LinearGradient(
                                          colors: [Colors.red.withValues(alpha: 0.8), Colors.deepOrange.withValues(alpha: 0.6)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          // Avatar background
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              session.hostAvatar,
                                              headers: SupabaseStore.getHeadersForUrl(session.hostAvatar),
                                              fit: BoxFit.cover,
                                              width: 140,
                                              height: 160,
                                              errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[800]),
                                            ),
                                          ),
                                          // Gradient overlay
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              gradient: LinearGradient(
                                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                            ),
                                          ),
                                          // LIVE badge
                                          Positioned(
                                            top: 8,
                                            left: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                "LIVE",
                                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          // Host name at bottom
                                          Positioned(
                                            bottom: 8,
                                            left: 8,
                                            right: 8,
                                            child: Text(
                                              session.hostName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, height: 1),
                        ],
                      );
                    }),
                    Expanded(child: _buildEmptyFeedState(context, textColor, textSecondary, isDark)),
                  ],
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await feedController.refreshData();
                },
                color: AppTheme.primary,
                backgroundColor: AppTheme.cardBg,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: followedClips.length,
                  itemBuilder: (context, index) {
                    return Obx(() {
                      return VideoFeedItem(clip: followedClips[index], isActive: index == feedController.focusedIndex.value);
                    });
                  },
                ),
              );
            }),
          ),
        ],
      ),

    );
  }
}

class VideoFeedItem extends StatefulWidget {
  final DanceClip clip;
  final bool isActive;
  final VoidCallback? onDeleteSuccess;

  const VideoFeedItem({super.key, required this.clip, required this.isActive, this.onDeleteSuccess});

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  late VideoFeedItemController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(VideoFeedItemController(clip: widget.clip), tag: widget.clip.id);
    _controller.setFocus(widget.isActive);
  }

  @override
  void didUpdateWidget(VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _controller.setFocus(widget.isActive);
    }
  }

  @override
  void dispose() {
    // Do NOT delete the controller — GetX manages its lifecycle via tag
    super.dispose();
  }

  void _showCommentsBottomSheet(BuildContext context) {
    final authService = Get.find<AuthController>();
    final currentUser = authService.currentUserProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to comment')));
      return;
    }

    final textController = TextEditingController();
    _controller.loadComments();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Obx(() {
            final comments = _controller.comments;
            final isLoading = _controller.isLoadingComments.value;

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Title
                  Text(
                    isLoading ? HomeFeedStrings.loadingComments : HomeFeedStrings.commentsCountText(comments.length),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, height: 1),

                  // Comments list
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                        : comments.isEmpty
                        ? const Center(child: Text(HomeFeedStrings.noCommentsYet))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundImage: NetworkImage(
                                        comment.avatarUrl,
                                        headers: SupabaseStore.getHeadersForUrl(comment.avatarUrl),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "@${comment.username}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          MentionText(
                                            text: comment.commentText,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Comment input box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: MentionAutocompleteWrapper(
                            controller: textController,
                            showAbove: true,
                            child: TextField(
                              controller: textController,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: HomeFeedStrings.addComment,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                          onPressed: () async {
                            if (textController.text.trim().isNotEmpty) {
                              await _controller.submitComment(textController.text.trim(), currentUser);
                              textController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  void _showEditPostDialog(BuildContext context) {
    final feedController = Get.find<FeedController>();
    final captionController = TextEditingController(text: widget.clip.caption);
    final styleController = TextEditingController(text: widget.clip.danceStyle);
    final musicController = TextEditingController(text: widget.clip.musicName);
    final artistController = TextEditingController(text: widget.clip.musicArtist);

    showDialog(
      context: context,
      builder: (context) {
        final dialogIsDark = Theme.of(context).brightness == Brightness.dark;
        final dialogTextColor = dialogIsDark ? Colors.white : Colors.black87;
        final dialogTextSecondary = dialogIsDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
        final dialogBorderColor = dialogIsDark ? AppTheme.darkBorder : AppTheme.lightBorder;

        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Post Details',
            style: TextStyle(color: dialogTextColor, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MentionAutocompleteWrapper(
                  controller: captionController,
                  child: TextField(
                    controller: captionController,
                    style: TextStyle(color: dialogTextColor),
                    decoration: InputDecoration(
                      labelText: 'Caption',
                      labelStyle: TextStyle(color: dialogTextSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogBorderColor)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
                    ),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: styleController,
                  style: TextStyle(color: dialogTextColor),
                  decoration: InputDecoration(
                    labelText: 'Dance Style',
                    labelStyle: TextStyle(color: dialogTextSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogBorderColor)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: musicController,
                  style: TextStyle(color: dialogTextColor),
                  decoration: InputDecoration(
                    labelText: 'Music Name',
                    labelStyle: TextStyle(color: dialogTextSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogBorderColor)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: artistController,
                  style: TextStyle(color: dialogTextColor),
                  decoration: InputDecoration(
                    labelText: 'Music Artist',
                    labelStyle: TextStyle(color: dialogTextSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogBorderColor)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                await feedController.updatePost(
                  widget.clip.id,
                  caption: captionController.text.trim(),
                  danceStyle: styleController.text.trim(),
                  musicName: musicController.text.trim(),
                  musicArtist: artistController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    final feedController = Get.find<FeedController>();
    showDialog(
      context: context,
      builder: (context) {
        final dialogIsDark = Theme.of(context).brightness == Brightness.dark;
        final dialogTextColor = dialogIsDark ? Colors.white : Colors.black87;
        final dialogTextSecondary = dialogIsDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Post?',
            style: TextStyle(color: dialogTextColor, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit'),
          ),
          content: Text(
            'Are you sure you want to delete this post? This action cannot be undone.',
            style: TextStyle(color: dialogTextSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await feedController.deletePost(widget.clip.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (widget.onDeleteSuccess != null) {
                    widget.onDeleteSuccess!();
                  }
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedController = Get.find<FeedController>();
    final authService = Get.find<AuthController>();
    final currentUser = authService.currentUserProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).colorScheme.surface;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Post Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (context) => ProfileScreen(userId: widget.clip.dancerUid)));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(
                        widget.clip.dancerAvatar,
                        headers: SupabaseStore.getHeadersForUrl(widget.clip.dancerAvatar),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => ProfileScreen(userId: widget.clip.dancerUid)),
                              );
                            },
                            child: Text(
                              widget.clip.dancerName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textColor,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: AppTheme.accent),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.clip.danceStyle,
                        style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                // Follow Button
                if (widget.clip.dancerUid != currentUser?.uid)
                  TextButton(
                    onPressed: () => feedController.toggleFollow(widget.clip.dancerUid),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      widget.clip.isFollowedByMe ? 'Following' : 'Follow',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.clip.isFollowedByMe
                            ? (isDark ? Colors.grey : Colors.grey[600])
                            : AppTheme.primary,
                      ),
                    ),
                  ),
                if (widget.clip.dancerUid == currentUser?.uid)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: textColor),
                    color: cardBg,
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditPostDialog(context);
                      } else if (value == 'delete') {
                        _showDeleteConfirmDialog(context);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, color: textColor, size: 18),
                            const SizedBox(width: 8),
                            Text('Edit Details', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            const Text('Delete Post', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 2. Media Player View
          CarouselMediaWidget(clip: widget.clip, isActive: widget.isActive),

          // 3. Actions Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => feedController.toggleLike(widget.clip.id),
                  child: Row(
                    children: [
                      AnimatedScale(
                        scale: widget.clip.isLikedByMe ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          widget.clip.isLikedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: widget.clip.isLikedByMe ? AppTheme.primary : textColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${widget.clip.likes}",
                        style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => _showCommentsBottomSheet(context),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, color: textColor, size: 23),
                      const SizedBox(width: 6),
                      Text(
                        "${widget.clip.commentsCount}",
                        style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(HomeFeedStrings.linkCopied), duration: Duration(seconds: 1)),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(Icons.reply_rounded, color: textColor, size: 26),
                      const SizedBox(width: 4),
                      Text(
                        "${widget.clip.sharesCount}",
                        style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. Caption & Music Details
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.clip.caption.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () async {
                      try {
                        final user = await SupabaseStore.instance.getUserProfile(widget.clip.dancerUid);
                        if (user != null && context.mounted) {
                          Navigator.of(
                            context,
                          ).push(MaterialPageRoute(builder: (context) => ProfileScreen(userId: user.uid)));
                        }
                      } catch (_) {}
                    },
                    child: Text(
                      "@${widget.clip.dancerName}",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  MentionText(
                    text: widget.clip.caption,
                    style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white70 : Colors.black87),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "${widget.clip.musicName} — ${widget.clip.musicArtist}",
                        style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

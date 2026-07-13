import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dance_pulse/app/controllers/auth_controller.dart';
import 'package:dance_pulse/app/modules/home_feed/feed_controller.dart';
import 'package:dance_pulse/app/modules/discovery/discovery_controller.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';
import 'package:dance_pulse/app/utils/app_strings.dart';
import 'package:dance_pulse/app/modules/messages/messages_screen.dart';
import 'package:dance_pulse/app/modules/profile/profile_screen.dart';
import 'package:dance_pulse/app/ui/widgets/clip_thumbnail_widget.dart';

class DiscoveryScreen extends StatelessWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DiscoveryController());
    final feedController = Get.find<FeedController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(DiscoveryStrings.discover),
        centerTitle: false,
        actions: [IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {})],
      ),
      body: Obx(() {
        final clips = feedController.clips;

        // Filter clips based on style & search query
        final filteredClips = clips.where((clip) {
          final matchesStyle =
              controller.selectedStyle.value == "All" ||
              clip.danceStyle.toLowerCase() == controller.selectedStyle.value.toLowerCase();
          final matchesSearch =
              clip.caption.toLowerCase().contains(controller.searchQuery.value.toLowerCase()) ||
              clip.dancerName.toLowerCase().contains(controller.searchQuery.value.toLowerCase()) ||
              clip.danceStyle.toLowerCase().contains(controller.searchQuery.value.toLowerCase());
          return matchesStyle && matchesSearch;
        }).toList();

        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.cardBg,
          onRefresh: () async {
            await feedController.refreshData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glowing Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: controller.searchController,
                      onChanged: controller.updateQuery,
                      decoration: InputDecoration(
                        hintText: DiscoveryStrings.searchPlaceholder,
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                        suffixIcon: controller.searchQuery.value.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                                onPressed: controller.clearQuery,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Style Chips Horizontal Scroll
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.styles.length,
                    itemBuilder: (context, index) {
                      final style = controller.styles[index];
                      final isSelected = controller.selectedStyle.value == style;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () => controller.setStyle(style),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected ? AppTheme.primaryGradient : null,
                              color: isSelected ? null : AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? Colors.transparent : AppTheme.border, width: 1),
                            ),
                            child: Text(
                              style,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                if (controller.searchQuery.value.isNotEmpty) ...[
                  Obx(() {
                    if (controller.isLoadingSearch.value) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                      );
                    }
                    final dancers = controller.matchingDancers;
                    if (dancers.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            DiscoveryStrings.matchingDancers,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 165,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: dancers.length,
                            itemBuilder: (context, index) {
                              final dancer = dancers[index];
                              final currentUser = Get.find<AuthController>().currentUserProfile;
                              final isMe = currentUser?.uid == dancer.uid;
                              final isFollowed = feedController.followedDancerUids.contains(dancer.uid);

                              return Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(
                                      context,
                                    ).push(MaterialPageRoute(builder: (context) => ProfileScreen(userId: dancer.uid)));
                                  },
                                  child: Container(
                                    width: 180,
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppTheme.border, width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundImage: NetworkImage(
                                              dancer.avatarUrl,
                                              headers: SupabaseStore.getHeadersForUrl(dancer.avatarUrl),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            dancer.displayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            "@${dancer.username}",
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (!isMe) ...[
                                                GestureDetector(
                                                  onTap: () => feedController.toggleFollow(dancer.uid),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      gradient: isFollowed ? null : AppTheme.primaryGradient,
                                                      color: isFollowed ? AppTheme.border.withValues(alpha: 0.3) : null,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      isFollowed ? "Unfollow" : "Follow",
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  onTap: () {
                                                    final room = feedController.getOrCreateChat(dancer);
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (context) => ChatRoomScreen(chatRoomId: room.id),
                                                      ),
                                                    ).then((_) {
                                                      feedController.safeUpdate();
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.accent.withValues(alpha: 0.15),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                                                    ),
                                                    child: const Icon(
                                                      Icons.mail_outline_rounded,
                                                      size: 14,
                                                      color: AppTheme.accent,
                                                    ),
                                                  ),
                                                ),
                                              ] else ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.border.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Text(
                                                    DiscoveryStrings.you,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }),
                ],

                // Videos Grid Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    controller.searchQuery.value.isNotEmpty
                        ? DiscoveryStrings.searchResults
                        : controller.selectedStyle.value == "All"
                        ? DiscoveryStrings.trendingClips
                        : DiscoveryStrings.popularClips(controller.selectedStyle.value),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 12),

                // Videos Grid Layout
                if (filteredClips.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Text(DiscoveryStrings.noClipsFound, style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredClips.length,
                    itemBuilder: (context, index) {
                      final clip = filteredClips[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(
                            context,
                          ).push(MaterialPageRoute(builder: (context) => ProfileScreen(userId: clip.dancerUid)));
                        },
                        child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
                          child: Stack(
                            children: [
                              Positioned.fill(child: ClipThumbnailWidget(clip: clip, borderRadius: 12)),
                              // Shadow overlay at bottom
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: const [0.6, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Top Dance Style indicator badge
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    clip.danceStyle,
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              // Likes & Dancer Name at bottom
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "@${clip.dancerName}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.favorite_rounded, size: 12, color: AppTheme.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${clip.likes}",
                                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

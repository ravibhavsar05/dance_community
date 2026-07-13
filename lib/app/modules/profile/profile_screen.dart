import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dance_pulse/app/controllers/auth_controller.dart';
import 'package:dance_pulse/app/modules/home_feed/feed_controller.dart';
import 'package:dance_pulse/app/controllers/theme_controller.dart';
import 'package:dance_pulse/app/modules/profile/profile_controller.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';
import 'package:dance_pulse/app/data/models/dance_models.dart';
import 'package:dance_pulse/app/modules/battle/widgets/battle_vote_card.dart';
import 'package:dance_pulse/app/utils/app_strings.dart';
import 'package:dance_pulse/app/modules/profile/profile_clip_feed_screen.dart';
import 'package:dance_pulse/app/modules/messages/messages_screen.dart';
import 'package:dance_pulse/app/ui/widgets/clip_thumbnail_widget.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String get _tag => widget.userId ?? 'me';

  @override
  void initState() {
    super.initState();
    // Register or find the profile controller, then load fresh data
    final profileController = Get.put(ProfileController(userId: widget.userId), tag: _tag);
    profileController.loadProfileData(widget.userId);
  }

  void _showEditProfileDialog(
    BuildContext context,
    AuthController authController,
    ProfileController profileController,
  ) {
    final nameController = TextEditingController(text: authController.currentUserProfile?.displayName);
    final bioController = TextEditingController(text: authController.currentUserProfile?.bio);
    String selectedGender = authController.currentUserProfile?.gender ?? "Male";
    DateTime? selectedDob = authController.currentUserProfile?.dateOfBirth;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text(ProfileStrings.editProfileDetails, style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(hintText: ProfileStrings.displayName),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: bioController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: ProfileStrings.danceBio),
                    ),
                    const SizedBox(height: 20),

                    // Gender Selector
                    const Text(
                      "Gender",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGender,
                      dropdownColor: AppTheme.cardBg,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: ["Male", "Female", "Other"].map((gender) {
                        return DropdownMenuItem(
                          value: gender,
                          child: Text(gender, style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedGender = val ?? "Male";
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Date of Birth DatePicker trigger
                    const Text(
                      "Date of Birth",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDob ?? DateTime(2000, 1, 1),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppTheme.primary,
                                  onPrimary: Colors.white,
                                  surface: AppTheme.cardBg,
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDob = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedDob == null
                                  ? "Select Date of Birth"
                                  : "${selectedDob!.day}/${selectedDob!.month}/${selectedDob!.year}",
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(ProfileStrings.cancel, style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await authController.updateProfile(
                      nameController.text.trim(),
                      bioController.text.trim(),
                      gender: selectedGender,
                      dateOfBirth: selectedDob,
                    );
                    profileController.loadProfileData(widget.userId); // refresh profile view
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(ProfileStrings.saveChanges),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileController = Get.find<ProfileController>(tag: _tag);
    return DefaultTabController(
      length: 3,
      child: Obx(() {
        if (profileController.isLoadingProfile.value && profileController.profile.value == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          );
        }

        final profile = profileController.profile.value;
        if (profile == null) {
          return const Scaffold(body: Center(child: Text(ProfileStrings.profileNotFound)));
        }

        return GetBuilder<ThemeController>(
          builder: (themeController) {
            return GetBuilder<AuthController>(
              builder: (authController) {
                return GetBuilder<FeedController>(
                  builder: (feedController) {
                    final isDark = themeController.isDarkMode;
                    final userClips = feedController.clips.where((c) => c.dancerUid == profile.uid).toList();

                    return Scaffold(
                      appBar: AppBar(
                        title: Text("@${profile.username}"),
                        leading: !profileController.isMe.value
                            ? IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                onPressed: () => Navigator.pop(context),
                              )
                            : null,
                        actions: [
                          if (profileController.isMe.value) ...[
                            // Theme toggler
                            IconButton(
                              icon: Icon(
                                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onPressed: () {
                                themeController.toggleTheme();
                              },
                            ),
                            // Logout
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                              onPressed: () async {
                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: AppTheme.cardBg,
                                    title: const Text(
                                      ProfileStrings.logoutConfirmTitle,
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    content: const Text(
                                      ProfileStrings.logoutConfirmContent,
                                      style: TextStyle(color: AppTheme.textSecondary),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text(
                                          ProfileStrings.cancel,
                                          style: TextStyle(color: Colors.white54),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text(
                                          ProfileStrings.logoutConfirmButton,
                                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await authController.signOut();
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                      body: Column(
                        children: [
                          // Top Header (Avatar, bio, stats)
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Dynamic Profile Icon / Image
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 46,
                                          backgroundImage: NetworkImage(
                                            profile.avatarUrl,
                                            headers: SupabaseStore.getHeadersForUrl(profile.avatarUrl),
                                          ),
                                        ),
                                        if (profileController.isMe.value)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: GestureDetector(
                                              onTap: () async {
                                                final ImagePicker picker = ImagePicker();
                                                final XFile? image = await picker.pickImage(
                                                  source: ImageSource.gallery,
                                                );
                                                if (image != null) {
                                                  final success = await authController.updateAvatar(image.path);
                                                  if (success && context.mounted) {
                                                    profileController.loadProfileData(widget.userId); // refresh
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(ProfileStrings.profilePictureUpdated),
                                                      ),
                                                    );
                                                  } else if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(ProfileStrings.profilePictureUpdateFailed),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: const BoxDecoration(
                                                  gradient: AppTheme.primaryGradient,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 24),

                                    // Stats Row - Only visible for self or followers
                                    Expanded(
                                      child: (profileController.isMe.value || profileController.isFollowing.value)
                                          ? Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                _buildStatColumn("Clips", userClips.length.toString()),
                                                _buildStatColumn("Wins", profileController.winCount.toString()),
                                                _buildStatColumn("Followers", _formatNumber(profile.followersCount)),
                                                _buildStatColumn("Likes", _formatNumber(profile.likesCount)),
                                              ],
                                            )
                                          : const Center(
                                              child: Text(
                                                ProfileStrings.followToViewMetrics,
                                                style: TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Display name & Bio details
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.displayName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                      if (profile.gender != null || profile.dateOfBirth != null) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            if (profile.gender != null) ...[
                                              Icon(
                                                profile.gender!.toLowerCase() == 'male'
                                                    ? Icons.male_rounded
                                                    : profile.gender!.toLowerCase() == 'female'
                                                    ? Icons.female_rounded
                                                    : Icons.transgender_rounded,
                                                size: 15,
                                                color: AppTheme.accent,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                profile.gender!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? AppTheme.darkTextSecondary
                                                      : AppTheme.lightTextSecondary,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                            ],
                                            if (profile.dateOfBirth != null) ...[
                                              const Icon(Icons.cake_rounded, size: 13, color: AppTheme.primary),
                                              const SizedBox(width: 4),
                                              Text(
                                                "${profile.dateOfBirth!.day}/${profile.dateOfBirth!.month}/${profile.dateOfBirth!.year}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? AppTheme.darkTextSecondary
                                                      : AppTheme.lightTextSecondary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      // Show bio only if self or followed
                                      if (profileController.isMe.value || profileController.isFollowing.value) ...[
                                        Text(
                                          profile.bio,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          children: profile.danceStyles.map((style) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: AppTheme.primary.withValues(alpha: 0.3),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                style,
                                                style: const TextStyle(
                                                  color: AppTheme.primary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Follow / Edit Profile Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: profileController.isMe.value
                                      ? OutlinedButton(
                                          onPressed: () =>
                                              _showEditProfileDialog(context, authController, profileController),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                              width: 1.5,
                                            ),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: Text(
                                            ProfileStrings.editPortfolioBio,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        )
                                      : profileController.isFollowing.value
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: profileController.toggleFollow,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.transparent,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    side: BorderSide(
                                                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  ProfileStrings.unfollowDancer,
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  final room = feedController.getOrCreateChat(profile);
                                                  Navigator.of(context)
                                                      .push(
                                                        MaterialPageRoute(
                                                          builder: (context) => ChatRoomScreen(chatRoomId: room.id),
                                                        ),
                                                      )
                                                      .then((_) {
                                                        feedController.safeUpdate();
                                                      });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.primary,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                child: const Text(
                                                  "Message",
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : ElevatedButton(
                                          onPressed: profileController.toggleFollow,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text(
                                            ProfileStrings.followDancer,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),

                          // --- FOLLOWER LOCK CONTENT CONTROLLER ---
                          if (!profileController.isMe.value && !profileController.isFollowing.value) ...[
                            const Divider(color: AppTheme.border, height: 1),
                            Expanded(
                              child: RefreshIndicator(
                                color: AppTheme.primary,
                                backgroundColor: AppTheme.cardBg,
                                onRefresh: () async {
                                  await Future.wait([
                                    profileController.loadProfileData(widget.userId),
                                    feedController.refreshData(),
                                  ]);
                                  setState(() {});
                                },
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      child: Container(
                                        height: constraints.maxHeight,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary.withValues(alpha: 0.08),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppTheme.primary.withValues(alpha: 0.2),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Icon(Icons.lock_rounded, size: 40, color: AppTheme.primary),
                                            ),
                                            const SizedBox(height: 20),
                                            const Text(
                                              ProfileStrings.privateProfile,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              ProfileStrings.privateProfileDesc,
                                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ] else ...[
                            // Tab Bar
                            TabBar(
                              indicatorColor: AppTheme.primary,
                              labelColor: AppTheme.primary,
                              unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              tabs: const [
                                Tab(icon: Icon(Icons.grid_on_rounded), text: "Clips"),
                                Tab(icon: Icon(Icons.favorite_border_rounded), text: "Likes"),
                                Tab(icon: Icon(Icons.emoji_events_outlined), text: "Battles"),
                              ],
                            ),

                            // Tab Bar View (User Clips / Liked Clips / Battles)
                            Expanded(
                              child: TabBarView(
                                children: [
                                  // User Clips Grid
                                  RefreshIndicator(
                                    color: AppTheme.primary,
                                    backgroundColor: AppTheme.cardBg,
                                    onRefresh: () async {
                                      await Future.wait([
                                        profileController.loadProfileData(widget.userId),
                                        feedController.refreshData(),
                                      ]);
                                      setState(() {});
                                    },
                                    child: userClips.isEmpty
                                        ? LayoutBuilder(
                                            builder: (context, constraints) {
                                              return SingleChildScrollView(
                                                physics: const AlwaysScrollableScrollPhysics(),
                                                child: Container(
                                                  height: constraints.maxHeight,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    ProfileStrings.noClips,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? AppTheme.darkTextSecondary
                                                          : AppTheme.lightTextSecondary,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : GridView.builder(
                                            physics: const AlwaysScrollableScrollPhysics(),
                                            padding: const EdgeInsets.all(8),
                                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              childAspectRatio: 0.75,
                                              crossAxisSpacing: 6,
                                              mainAxisSpacing: 6,
                                            ),
                                            itemCount: userClips.length,
                                            itemBuilder: (context, index) {
                                              final clip = userClips[index];
                                              return GestureDetector(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          ProfileClipFeedScreen(clips: userClips, initialIndex: index),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                    color: Colors.black,
                                                  ),
                                                  child: Stack(
                                                    children: [
                                                      Positioned.fill(
                                                        child: ClipThumbnailWidget(clip: clip, borderRadius: 8),
                                                      ),
                                                      Positioned(
                                                        bottom: 6,
                                                        left: 6,
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              clip.mediaItems.isNotEmpty &&
                                                                      clip.mediaItems.first['type'] == 'video'
                                                                  ? Icons.play_arrow_outlined
                                                                  : Icons.favorite,
                                                              size: 14,
                                                              color:
                                                                  clip.mediaItems.isNotEmpty &&
                                                                      clip.mediaItems.first['type'] == 'video'
                                                                  ? Colors.white
                                                                  : AppTheme.primary,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              "${clip.likes}",
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                              ),
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
                                  ),

                                  // Liked Clips Grid from Database
                                  RefreshIndicator(
                                    color: AppTheme.primary,
                                    backgroundColor: AppTheme.cardBg,
                                    onRefresh: () async {
                                      await Future.wait([
                                        profileController.loadProfileData(widget.userId),
                                        feedController.refreshData(),
                                      ]);
                                      setState(() {});
                                    },
                                    child: FutureBuilder<List<DanceClip>>(
                                      future: feedController.getLikedClips(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const Center(
                                            child: CircularProgressIndicator(color: AppTheme.primary),
                                          );
                                        }
                                        final likedClips = snapshot.data ?? [];
                                        if (likedClips.isEmpty) {
                                          return LayoutBuilder(
                                            builder: (context, constraints) {
                                              return SingleChildScrollView(
                                                physics: const AlwaysScrollableScrollPhysics(),
                                                child: Container(
                                                  height: constraints.maxHeight,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    ProfileStrings.noLikedClips,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? AppTheme.darkTextSecondary
                                                          : AppTheme.lightTextSecondary,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        }
                                        return GridView.builder(
                                          physics: const AlwaysScrollableScrollPhysics(),
                                          padding: const EdgeInsets.all(8),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            childAspectRatio: 0.75,
                                            crossAxisSpacing: 6,
                                            mainAxisSpacing: 6,
                                          ),
                                          itemCount: likedClips.length,
                                          itemBuilder: (context, index) {
                                            final clip = likedClips[index];
                                            return GestureDetector(
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        ProfileClipFeedScreen(clips: likedClips, initialIndex: index),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8),
                                                  color: Colors.black,
                                                ),
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: ClipThumbnailWidget(clip: clip, borderRadius: 8),
                                                    ),
                                                    Positioned(
                                                      bottom: 6,
                                                      left: 6,
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.favorite, size: 12, color: AppTheme.primary),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            "${clip.likes}",
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),

                                  // Battles Tab
                                  RefreshIndicator(
                                    color: AppTheme.primary,
                                    backgroundColor: AppTheme.cardBg,
                                    onRefresh: () async {
                                      await Future.wait([
                                        profileController.loadProfileData(widget.userId),
                                        feedController.refreshData(),
                                      ]);
                                      setState(() {});
                                    },
                                    child: profileController.isLoadingBattles.value
                                        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                                        : profileController.userBattles.isEmpty
                                        ? LayoutBuilder(
                                            builder: (context, constraints) {
                                              return SingleChildScrollView(
                                                physics: const AlwaysScrollableScrollPhysics(),
                                                child: Container(
                                                  height: constraints.maxHeight,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    ProfileStrings.noBattles,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? AppTheme.darkTextSecondary
                                                          : AppTheme.lightTextSecondary,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : ListView.builder(
                                            physics: const AlwaysScrollableScrollPhysics(),
                                            padding: const EdgeInsets.all(12),
                                            itemCount: profileController.userBattles.length,
                                            itemBuilder: (context, index) {
                                              return BattleVoteCard(battle: profileController.userBattles[index]);
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      }),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return "${(number / 1000000).toStringAsFixed(1)}M";
    } else if (number >= 1000) {
      return "${(number / 1000).toStringAsFixed(1)}K";
    }
    return number.toString();
  }
}

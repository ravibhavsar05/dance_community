import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:dance_pulse/app/data/models/dance_models.dart';
import 'package:dance_pulse/app/modules/battle/battle_vote_controller.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';
import 'package:dance_pulse/app/utils/app_strings.dart';
import 'package:dance_pulse/app/ui/widgets/mention_autocomplete_wrapper.dart';
import 'package:dance_pulse/app/modules/home_feed/widgets/mention_text.dart';

class BattleVoteCard extends StatelessWidget {
  static const int votingDurationHours = 48;
  final DanceBattle battle;

  const BattleVoteCard({
    super.key,
    required this.battle,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BattleVoteController>(
      init: BattleVoteController(battle: battle),
      tag: battle.id,
      dispose: (state) => Get.delete<BattleVoteController>(tag: battle.id),
      builder: (controller) {
        return Obx(() {
          if (controller.user1Profile.value == null || controller.user2Profile.value == null) {
            return Container(
              height: 380,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            );
          }

          final double totalVotes = (controller.user1Votes.value + controller.user2Votes.value).toDouble();
          final double user1Percentage = totalVotes > 0 ? (controller.user1Votes.value / totalVotes) * 100 : 50;
          final double user2Percentage = totalVotes > 0 ? (controller.user2Votes.value / totalVotes) * 100 : 50;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row (Turn Info / Creator vs Opponent title)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.flash_on_rounded, color: AppTheme.accent, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                BattleVoteCardStrings.showdownHeader,
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 0.8),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: controller.isVotingExpired.value ? Colors.white12 : AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          controller.timeRemainingText.value,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: controller.isVotingExpired.value ? AppTheme.textSecondary : AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Split-screen combined video preview
                AspectRatio(
                  aspectRatio: 1.33, // Widescreen side-by-side combined video aspect ratio
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        controller.isVideoInitialized.value && controller.videoController.value != null
                            ? GestureDetector(
                                onTap: () => controller.togglePlayPause(),
                                child: VideoPlayer(controller.videoController.value!),
                              )
                            : controller.hasVideoError.value
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.video_library_rounded, size: 40, color: Colors.white24),
                                        SizedBox(height: 8),
                                        Text(BattleVoteCardStrings.videoUnavailable, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                      ],
                                    ),
                                  )
                                : controller.isVideoLoading.value
                                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                                    : GestureDetector(
                                        onTap: () => controller.initializeAndPlay(),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.secondary.withValues(alpha: 0.15),
                                                AppTheme.primary.withValues(alpha: 0.15),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Transform.translate(
                                                    offset: const Offset(8, 0),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: AppTheme.primary.withValues(alpha: 0.3),
                                                            blurRadius: 8,
                                                            spreadRadius: 1,
                                                          ),
                                                        ],
                                                        border: Border.all(color: AppTheme.primary, width: 2),
                                                      ),
                                                      child: CircleAvatar(
                                                        radius: 26,
                                                        backgroundImage: NetworkImage(
                                                          controller.user1Profile.value!.avatarUrl,
                                                          headers: SupabaseStore.getHeadersForUrl(controller.user1Profile.value!.avatarUrl),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Transform.translate(
                                                    offset: const Offset(-8, 0),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: AppTheme.secondary.withValues(alpha: 0.3),
                                                            blurRadius: 8,
                                                            spreadRadius: 1,
                                                          ),
                                                        ],
                                                        border: Border.all(color: AppTheme.secondary, width: 2),
                                                      ),
                                                      child: CircleAvatar(
                                                        radius: 26,
                                                        backgroundImage: NetworkImage(
                                                          controller.user2Profile.value!.avatarUrl,
                                                          headers: SupabaseStore.getHeadersForUrl(controller.user2Profile.value!.avatarUrl),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.5),
                                                  borderRadius: BorderRadius.circular(30),
                                                  border: Border.all(
                                                    color: Colors.white.withValues(alpha: 0.2),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.play_arrow_rounded,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      "TAP TO WATCH BATTLE",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 12,
                                                        letterSpacing: 1.0,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                        // VS overlay
                        if (controller.isVideoInitialized.value)
                          IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                BattleVoteCardStrings.vs,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ),

                        // Play/Pause Overlay indicator
                        if (controller.isVideoInitialized.value && controller.videoController.value != null)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () => controller.togglePlayPause(),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  controller.videoController.value!.value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Likes & Comments Actions Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      // Like Battle
                      GestureDetector(
                        onTap: () => controller.toggleLike(),
                        child: Row(
                          children: [
                            Icon(
                              controller.isLikedByMe.value ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: controller.isLikedByMe.value ? AppTheme.primary : Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${controller.likes.value}",
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Comment Battle
                      GestureDetector(
                        onTap: () => _showCommentsBottomSheet(context, controller),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              "${controller.commentsCount.value}",
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Dancer Names and Stats block
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Winner/Loser Badges if Voting Expired or Forfeited
                      if (controller.isVotingExpired.value || battle.forfeitWinnerUid != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Dancer 1 Badge
                            _buildResultBadge(
                              userId: battle.user1Uid,
                              isForfeit: battle.forfeitWinnerUid != null,
                              isWinner: battle.forfeitWinnerUid != null 
                                  ? battle.forfeitWinnerUid == battle.user1Uid 
                                  : controller.user1Votes.value > controller.user2Votes.value,
                              isTie: battle.forfeitWinnerUid == null && controller.user1Votes.value == controller.user2Votes.value,
                              percentage: user1Percentage,
                            ),
                            
                            // Dancer 2 Badge
                            _buildResultBadge(
                              userId: battle.user2Uid,
                              isForfeit: battle.forfeitWinnerUid != null,
                              isWinner: battle.forfeitWinnerUid != null 
                                  ? battle.forfeitWinnerUid == battle.user2Uid 
                                  : controller.user2Votes.value > controller.user1Votes.value,
                              isTie: battle.forfeitWinnerUid == null && controller.user1Votes.value == controller.user2Votes.value,
                              percentage: user2Percentage,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Dancer 1 Name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      controller.user1Profile.value!.displayName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (controller.votedForUid.value == battle.user1Uid) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.primary, width: 0.5),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.local_fire_department_rounded, color: AppTheme.primary, size: 10),
                                            SizedBox(width: 2),
                                            Text("YOUR VOTE", style: TextStyle(color: AppTheme.primary, fontSize: 8, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  "@${controller.user1Profile.value!.username}",
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                          // Dancer 2 Name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (controller.votedForUid.value == battle.user2Uid) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.secondary.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.secondary, width: 0.5),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.local_fire_department_rounded, color: AppTheme.secondary, size: 10),
                                            SizedBox(width: 2),
                                            Text("YOUR VOTE", style: TextStyle(color: AppTheme.secondary, fontSize: 8, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      controller.user2Profile.value!.displayName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                Text(
                                  "@${controller.user2Profile.value!.username}",
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Voting progress meter / results
                      if (controller.isVotingExpired.value) ...[
                        Column(
                          children: [
                            // Stats Row values
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  BattleVoteCardStrings.votesPercentage(controller.user1Votes.value, user1Percentage.toStringAsFixed(0)),
                                  style: TextStyle(
                                    fontSize: 12, 
                                    fontWeight: FontWeight.bold, 
                                    color: user1Percentage >= user2Percentage ? AppTheme.accent : Colors.white70
                                  ),
                                ),
                                Text(
                                  BattleVoteCardStrings.votesPercentage(controller.user2Votes.value, user2Percentage.toStringAsFixed(0)),
                                  style: TextStyle(
                                    fontSize: 12, 
                                    fontWeight: FontWeight.bold, 
                                    color: user2Percentage >= user1Percentage ? AppTheme.accent : Colors.white70
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: 10,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: user1Percentage.round(),
                                      child: Container(color: AppTheme.primary),
                                    ),
                                    Expanded(
                                      flex: user2Percentage.round(),
                                      child: Container(color: AppTheme.secondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (controller.hasVoted.value) ...[
                        // If they have voted but voting is not expired yet
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Vote cast successfully! Results will be revealed when voting completes.",
                                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // --- VOTE CAST INTERACTION (DRAG AND DROP) ---
                      if (!controller.isParticipant.value && !controller.hasVoted.value && !controller.isVotingExpired.value && !controller.isLoadingStatus.value) ...[
                        if (controller.isFollower.value) ...[
                          const Divider(color: AppTheme.border, height: 28),
                          const Text(
                            BattleVoteCardStrings.dragTokenPrompt,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 16),

                          // Drop targets and Draggable Token row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Target User 1
                              DragTarget<String>(
                                onAcceptWithDetails: (details) {
                                  if (details.data == "ballot") {
                                    controller.castVote(battle.user1Uid, context);
                                  }
                                },
                                builder: (context, candidateData, rejectedData) {
                                  final isHovered = candidateData.isNotEmpty;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: isHovered ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isHovered ? AppTheme.primary : AppTheme.border,
                                        width: isHovered ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: NetworkImage(
                                            controller.user1Profile.value!.avatarUrl,
                                            headers: SupabaseStore.getHeadersForUrl(controller.user1Profile.value!.avatarUrl),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text("VOTE HERE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // Draggable Token (Flame ballot icon)
                              Draggable<String>(
                                data: "ballot",
                                feedback: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: const BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 30),
                                ),
                                childWhenDragging: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppTheme.border.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.local_fire_department_rounded, color: Colors.white24, size: 30),
                                ),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 30),
                                ),
                              ),

                              // Target User 2
                              DragTarget<String>(
                                onAcceptWithDetails: (details) {
                                  if (details.data == "ballot") {
                                    controller.castVote(battle.user2Uid, context);
                                  }
                                },
                                builder: (context, candidateData, rejectedData) {
                                  final isHovered = candidateData.isNotEmpty;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: isHovered ? AppTheme.secondary.withValues(alpha: 0.2) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isHovered ? AppTheme.secondary : AppTheme.border,
                                        width: isHovered ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: NetworkImage(
                                            controller.user2Profile.value!.avatarUrl,
                                            headers: SupabaseStore.getHeadersForUrl(controller.user2Profile.value!.avatarUrl),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text("VOTE HERE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          const Divider(color: AppTheme.border, height: 28),
                          const Center(
                            child: Text(
                              BattleVoteCardStrings.followToVote,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ] else if (controller.isParticipant.value) ...[
                        const Divider(color: AppTheme.border, height: 28),
                        const Center(
                          child: Text(
                            BattleVoteCardStrings.participantsCannotVote,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.8),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showCommentsBottomSheet(BuildContext context, BattleVoteController controller) {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: FutureBuilder<List<Comment>>(
                future: controller.getComments(),
                builder: (context, snapshot) {
                  final comments = snapshot.data ?? [];
                  final isLoading = snapshot.connectionState == ConnectionState.waiting;

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
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        
                        // Title
                        Text(
                          isLoading ? HomeFeedStrings.loadingComments : HomeFeedStrings.commentsCountText(comments.length),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: AppTheme.border, height: 1),
                        
                        // Comments list
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                              : comments.isEmpty
                                  ? const Center(child: Text(HomeFeedStrings.noCommentsYet, style: TextStyle(color: AppTheme.textSecondary)))
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
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 13,
                                                        color: AppTheme.textSecondary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                     MentionText(
                                                       text: comment.commentText,
                                                       style: const TextStyle(fontSize: 14, color: Colors.white),
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
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
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
                                    style: const TextStyle(fontSize: 14, color: Colors.white),
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
                                    await controller.addComment(
                                      textController.text.trim(),
                                      controller.me,
                                    );
                                    setModalState(() {});
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
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResultBadge({
    required String userId,
    required bool isForfeit,
    required bool isWinner,
    required bool isTie,
    required double percentage,
  }) {
    Color badgeColor;
    String text;

    if (isForfeit) {
      if (isWinner) {
        badgeColor = Colors.green;
        text = BattleVoteCardStrings.winnerForfeit;
      } else {
        badgeColor = Colors.redAccent;
        text = BattleVoteCardStrings.loserForfeit;
      }
    } else if (isTie) {
      badgeColor = AppTheme.accent;
      text = BattleVoteCardStrings.tiePercent(percentage.toStringAsFixed(0));
    } else if (isWinner) {
      badgeColor = Colors.green;
      text = BattleVoteCardStrings.winnerPercent(percentage.toStringAsFixed(0));
    } else {
      badgeColor = Colors.grey[700]!;
      text = BattleVoteCardStrings.loserPercent(percentage.toStringAsFixed(0));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: badgeColor,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:firebasecrashreport/app/utils/app_logger.dart';
import 'package:firebasecrashreport/app/data/models/dance_models.dart';
import 'package:firebasecrashreport/app/data/services/supabase_store.dart';
import 'package:firebasecrashreport/app/utils/app_strings.dart';
import 'package:firebasecrashreport/app/controllers/auth_controller.dart';

class BattleVoteController extends GetxController {
  final DanceBattle battle;
  
  BattleVoteController({required this.battle});

  final Rxn<VideoPlayerController> videoController = Rxn<VideoPlayerController>();
  final RxBool isVideoInitialized = false.obs;
  final RxBool hasVideoError = false.obs;
  final RxBool isVideoLoading = false.obs;

  // Profiles
  final Rxn<DancerProfile> user1Profile = Rxn<DancerProfile>();
  final Rxn<DancerProfile> user2Profile = Rxn<DancerProfile>();
  late DancerProfile me;

  // Eligibility & Voting state
  final RxBool isParticipant = false.obs;
  final RxBool isFollower = false.obs;
  final RxBool hasVoted = false.obs;
  final RxnString votedForUid = RxnString();
  final RxBool isLoadingStatus = true.obs;
  final RxInt user1Votes = 0.obs;
  final RxInt user2Votes = 0.obs;

  // Likes & Comments
  final RxInt likes = 0.obs;
  final RxInt commentsCount = 0.obs;
  final RxBool isLikedByMe = false.obs;

  // Timer
  Timer? _countdownTimer;
  final RxString timeRemainingText = "".obs;
  final RxBool isVotingExpired = false.obs;

  @override
  void onInit() {
    super.onInit();
    me = Get.find<AuthController>().currentUserProfile!;
    user1Votes.value = battle.user1Votes;
    user2Votes.value = battle.user2Votes;
    likes.value = battle.likes;
    commentsCount.value = battle.commentsCount;

    _loadProfilesAndCheckEligibility();
    _startCountdownTimer();
  }

  void initializeAndPlay() async {
    if (isVideoInitialized.value) {
      togglePlayPause();
      return;
    }

    final videoUrl = battle.combinedVideoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      hasVideoError.value = true;
      return;
    }

    isVideoLoading.value = true;
    update();

    try {
      if (videoUrl.startsWith('http')) {
        videoController.value = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          httpHeaders: SupabaseStore.getHeadersForUrl(videoUrl) ?? const {},
        );
      } else {
        videoController.value = VideoPlayerController.file(File(videoUrl));
      }

      await videoController.value!.initialize();
      videoController.value!.setLooping(true);
      
      isVideoInitialized.value = true;
      videoController.value!.play();
    } catch (e) {
      appLog("Video init failed in BattleVoteCard: $e");
      hasVideoError.value = true;
    } finally {
      isVideoLoading.value = false;
      update();
    }
  }

  void _loadProfilesAndCheckEligibility() async {
    final u1 = await SupabaseStore.instance.getUserProfile(battle.user1Uid);
    final u2 = await SupabaseStore.instance.getUserProfile(battle.user2Uid);

    final resolvedU1 = u1 ?? DancerProfile(
      uid: battle.user1Uid,
      username: "dancer_1",
      displayName: "Dancer 1",
      avatarUrl: defaultAvatarUrl,
      bio: "Dancing is life! 🕺",
      followersCount: 0,
      followingCount: 0,
      likesCount: 0,
      danceStyles: const ["All Styles"],
    );

    final resolvedU2 = u2 ?? DancerProfile(
      uid: battle.user2Uid,
      username: "dancer_2",
      displayName: "Dancer 2",
      avatarUrl: defaultAvatarUrl,
      bio: "Dancing is life! 🕺",
      followersCount: 0,
      followingCount: 0,
      likesCount: 0,
      danceStyles: const ["All Styles"],
    );

    isParticipant.value = battle.user1Uid == me.uid || battle.user2Uid == me.uid;

    // Check if voter follows either dancer (participants are not voter eligible, followers are)
    final followsUser1 = await SupabaseStore.instance.checkIsFollowing(me.uid, battle.user1Uid);
    final followsUser2 = await SupabaseStore.instance.checkIsFollowing(me.uid, battle.user2Uid);
    
    // Check if they have already voted in this battle
    final votedFor = await SupabaseStore.instance.getVotedForUid(battle.id, me.uid);
    hasVoted.value = votedFor != null;
    votedForUid.value = votedFor;

    // Check if they liked the battle
    final liked = await SupabaseStore.instance.checkBattleIsLiked(battle.id, me.uid);
    isLikedByMe.value = liked;

    // Load latest likes/comments from DB
    final updatedBattle = await SupabaseStore.instance.getBattle(battle.id);
    if (updatedBattle != null) {
      likes.value = updatedBattle.likes;
      commentsCount.value = updatedBattle.commentsCount;
    }

    user1Profile.value = resolvedU1;
    user2Profile.value = resolvedU2;
    isFollower.value = followsUser1 || followsUser2;
    isLoadingStatus.value = false;
    
    _checkAndResolveWinner();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final diff = battle.votingEndsAt.difference(now);

      if (diff.isNegative) {
        _countdownTimer?.cancel();
        timeRemainingText.value = BattleVoteCardStrings.votingCompleted;
        isVotingExpired.value = true;
      } else {
        final hours = diff.inHours;
        final minutes = diff.inMinutes % 60;
        final seconds = diff.inSeconds % 60;
        timeRemainingText.value = BattleVoteCardStrings.votingEndsIn(hours, minutes, seconds);
        isVotingExpired.value = false;
      }
    });
  }

  void castVote(String votedForUidParam, BuildContext context) async {
    try {
      hasVoted.value = true;
      votedForUid.value = votedForUidParam;
      if (votedForUidParam == battle.user1Uid) {
        user1Votes.value++;
      } else {
        user2Votes.value++;
      }

      await SupabaseStore.instance.voteInBattle(battle.id, me.uid, votedForUidParam);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(BattleVoteCardStrings.voteSuccess)),
        );
      }
    } catch (e) {
      appLog("Failed to vote: $e");
    }
  }

  void togglePlayPause() {
    if (videoController.value == null || !isVideoInitialized.value) return;
    if (videoController.value!.value.isPlaying) {
      videoController.value!.pause();
    } else {
      videoController.value!.play();
    }
    videoController.refresh();
  }

  void toggleLike() async {
    try {
      // Optimistic update
      if (isLikedByMe.value) {
        likes.value--;
        isLikedByMe.value = false;
      } else {
        likes.value++;
        isLikedByMe.value = true;
      }
      update();

      final result = await SupabaseStore.instance.toggleBattleLike(battle.id, me.uid);
      likes.value = result['likes'] as int;
      isLikedByMe.value = result['isLikedByMe'] as bool;
      update();
    } catch (e) {
      appLog("Error toggling battle like: $e");
    }
  }

  Future<List<Comment>> getComments() async {
    try {
      return await SupabaseStore.instance.getBattleComments(battle.id);
    } catch (e) {
      appLog("Error fetching battle comments: $e");
      return [];
    }
  }

  Future<void> addComment(String commentText, DancerProfile user) async {
    final comment = Comment(
      id: "comment_${DateTime.now().millisecondsSinceEpoch}",
      username: user.username,
      avatarUrl: user.avatarUrl,
      commentText: commentText,
      timestamp: DateTime.now(),
    );

    // Optimistically update commentsCount
    commentsCount.value++;
    update();

    try {
      await SupabaseStore.instance.addBattleComment(battle.id, comment);
      
      // Reload latest counts
      final updatedBattle = await SupabaseStore.instance.getBattle(battle.id);
      if (updatedBattle != null) {
        commentsCount.value = updatedBattle.commentsCount;
        update();
      }
    } catch (e) {
      appLog("Error adding battle comment: $e");
    }
  }

  void _checkAndResolveWinner() async {
    if (battle.winnerUid != null || battle.forfeitWinnerUid != null) return;
    
    // We only resolve if the voting has actually ended
    final now = DateTime.now();
    if (!battle.votingEndsAt.isBefore(now)) return;

    String? winnerUid;
    if (user1Votes.value > user2Votes.value) {
      winnerUid = battle.user1Uid;
    } else if (user2Votes.value > user1Votes.value) {
      winnerUid = battle.user2Uid;
    }

    if (winnerUid != null) {
      await SupabaseStore.instance.resolveBattleWinner(battle.id, winnerUid);
    }
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    videoController.value?.dispose();
    super.onClose();
  }
}

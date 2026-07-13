import 'package:get/get.dart';
import 'package:firebasecrashreport/app/utils/app_logger.dart';
import '../data/models/dance_models.dart';
import '../data/services/supabase_store.dart';
import 'auth_controller.dart';
import 'feed_controller.dart';

import 'navigation_controller.dart';

class ProfileController extends GetxController {
  final String? userId;

  ProfileController({this.userId});

  final Rxn<DancerProfile> profile = Rxn<DancerProfile>();
  final RxBool isMe = true.obs;
  final RxBool isFollowing = false.obs;
  final RxBool isLoadingProfile = true.obs;
  final RxList<DanceBattle> userBattles = <DanceBattle>[].obs;
  final RxBool isLoadingBattles = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProfileData(userId);

    // If this is the "me" profile, listen to navigation tab changes to auto-refresh when tab index is clicked
    if (userId == null) {
      try {
        if (Get.isRegistered<NavigationController>()) {
          final navCtrl = Get.find<NavigationController>();
          ever(navCtrl.currentIndex, (index) {
            if (index == 4) {
              // 4 is the Profile tab index in NavigationWrapper
              loadProfileData(null);
            }
          });
        }
      } catch (e) {
        appLog("Error setting up navigation listener: $e");
      }
    }
  }

  int get winCount {
    if (profile.value == null) return 0;
    return userBattles.where((b) => b.winnerUid == profile.value!.uid).length;
  }

  Future<void> loadProfileData(String? userId) async {
    if (profile.value == null) {
      isLoadingProfile.value = true;
    }

    final authController = Get.find<AuthController>();
    final me = authController.currentUserProfile;
    if (me == null) {
      isLoadingProfile.value = false;
      return;
    }

    try {
      if (userId == null || userId == me.uid) {
        isMe.value = true;
        isFollowing.value = false;

        // Fetch fresh profile details from DB to refresh follower/following counts
        final freshProfile = await SupabaseStore.instance.getUserProfile(me.uid);
        if (freshProfile != null) {
          profile.value = freshProfile;
          authController.currentUserProfile = freshProfile;
        } else {
          profile.value = me;
        }
      } else {
        isMe.value = false;
        profile.value = await SupabaseStore.instance.getUserProfile(userId);
        isFollowing.value = await SupabaseStore.instance.checkIsFollowing(me.uid, userId);
      }
    } catch (e) {
      appLog("Error loading profile data: $e");
    } finally {
      isLoadingProfile.value = false;
    }

    if (isMe.value || isFollowing.value) {
      loadBattles();
    }
  }

  void loadBattles() async {
    if (profile.value == null) return;
    isLoadingBattles.value = true;
    try {
      final battles = await SupabaseStore.instance.getBattlesForUser(profile.value!.uid);
      userBattles.value = battles;
    } catch (e) {
      appLog("Error in loadBattles: $e");
    } finally {
      isLoadingBattles.value = false;
    }
  }

  Future<void> toggleFollow() async {
    if (profile.value == null) return;
    final feedController = Get.find<FeedController>();

    // Toggle follow in database
    await feedController.toggleFollow(profile.value!.uid);

    // Toggle local follow state
    isFollowing.value = !isFollowing.value;

    // Reload profile and battles based on follow status
    loadProfileData(profile.value!.uid);
  }
}

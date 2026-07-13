import 'package:get/get.dart';
import 'package:dance_pulse/app/controllers/theme_controller.dart';
import 'package:dance_pulse/app/controllers/auth_controller.dart';
import 'package:dance_pulse/app/modules/home_feed/feed_controller.dart';
import 'package:dance_pulse/app/data/services/battle_audio_service.dart';
import 'package:dance_pulse/app/modules/live_stream/live_stream_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ThemeController>(ThemeController(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<FeedController>(FeedController(), permanent: true);
    Get.put<BattleAudioService>(BattleAudioService(), permanent: true);
    Get.put<LiveStreamController>(LiveStreamController(), permanent: true);
  }
}

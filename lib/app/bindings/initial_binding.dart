import 'package:get/get.dart';
import 'package:firebasecrashreport/app/controllers/theme_controller.dart';
import 'package:firebasecrashreport/app/controllers/auth_controller.dart';
import 'package:firebasecrashreport/app/modules/home_feed/feed_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ThemeController>(ThemeController(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<FeedController>(FeedController(), permanent: true);
  }
}

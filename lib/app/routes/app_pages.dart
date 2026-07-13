import 'package:get/get.dart';
import 'package:firebasecrashreport/app/modules/login/login_screen.dart';
import 'package:firebasecrashreport/app/modules/navigation_wrapper/navigation_wrapper.dart';
import 'package:firebasecrashreport/app/modules/splash/splash_screen.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashScreen(),
    ),
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginScreen(),
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => const NavigationWrapper(),
    ),
  ];
}

import 'package:get/get.dart';
import 'package:dance_pulse/app/modules/login/login_screen.dart';
import 'package:dance_pulse/app/modules/navigation_wrapper/navigation_wrapper.dart';
import 'package:dance_pulse/app/modules/splash/splash_screen.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  // ignore: duplicate_ignore
  // ignore: constant_identifier_names
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

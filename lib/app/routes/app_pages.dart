import 'package:get/get.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/navigation_wrapper.dart';
import '../ui/screens/splash_screen.dart';

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

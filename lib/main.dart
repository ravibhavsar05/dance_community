import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebasecrashreport/app/ui/theme/app_theme.dart';
import 'package:firebasecrashreport/app/controllers/theme_controller.dart';
import 'package:firebasecrashreport/app/controllers/auth_controller.dart';
import 'package:firebasecrashreport/app/bindings/initial_binding.dart';
import 'package:firebasecrashreport/app/routes/app_pages.dart';
import 'package:firebasecrashreport/app/modules/login/login_screen.dart';
import 'package:firebasecrashreport/app/modules/navigation_wrapper/navigation_wrapper.dart';
import 'package:firebasecrashreport/app/modules/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    );
  const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    );

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  runApp(const DancePulseApp());
}

class DancePulseApp extends StatelessWidget {
  const DancePulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      init: ThemeController(),
      builder: (themeController) {
        return GetBuilder<AuthController>(
          init: AuthController(),
          builder: (authController) {
            return GetMaterialApp(
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                // ignore: deprecated_member_use
                final textScaleFactor = mediaQuery.textScaleFactor;
                if (textScaleFactor > 1.0) {
                  return MediaQuery(
                    data: mediaQuery.copyWith(textScaler: TextScaler.linear(1.25)),
                    child: child!,
                  );
                }
                if (textScaleFactor < 1.0) {
                  return MediaQuery(
                    data: mediaQuery.copyWith(textScaler: TextScaler.linear(1.0)),
                    child: child!,
                  );
                }
                return MediaQuery(
                  data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScaleFactor)),
                  child: child!,
                );
              },
              title: 'Dance Pulse',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeController.themeMode,
              initialBinding: InitialBinding(),
              getPages: AppPages.routes,
              home: authController.isLoading
                  ? const SplashScreen()
                  : authController.isLoggedIn
                  ? const NavigationWrapper()
                  : const LoginScreen(),
            );
          },
        );
      },
    );
  }
}

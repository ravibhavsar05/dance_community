import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';
import 'package:dance_pulse/app/controllers/theme_controller.dart';
import 'package:dance_pulse/app/controllers/auth_controller.dart';
import 'package:dance_pulse/app/bindings/initial_binding.dart';
import 'package:dance_pulse/app/routes/app_pages.dart';
import 'package:dance_pulse/app/modules/login/login_screen.dart';
import 'package:dance_pulse/app/modules/navigation_wrapper/navigation_wrapper.dart';
import 'package:dance_pulse/app/modules/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 64),
                    const SizedBox(height: 24),
                    const Text(
                      'Configuration Required',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Supabase environment variables (SUPABASE_URL and SUPABASE_ANON_KEY) are missing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To run the application locally:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '1. Copy .env.example to .env\n'
                            '2. Set your Supabase credentials in .env\n'
                            '3. Choose the "Dance Pulse" launch configuration in VS Code or Android Studio to run with one click,\n'
                            '   OR run in terminal: flutter run --dart-define-from-file=.env',
                            style: TextStyle(fontFamily: 'Courier', fontSize: 13, color: Colors.amberAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

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

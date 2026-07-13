import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/login_controller.dart';
import '../theme/app_theme.dart';
import 'app_strings.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final loginController = Get.put(LoginController());

    return GetBuilder<AuthController>(
      builder: (authService) {
        return Scaffold(
          body: Stack(
            children: [
              // Background Gradient decoration
              Positioned(
                top: -size.height * 0.2,
                right: -size.width * 0.2,
                child: Container(
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppTheme.secondary.withValues(alpha: 0.15), blurRadius: 120, spreadRadius: 60),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -size.height * 0.2,
                left: -size.width * 0.2,
                child: Container(
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppTheme.primary.withValues(alpha: 0.12), blurRadius: 120, spreadRadius: 60),
                    ],
                  ),
                ),
              ),

              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Obx(() {
                      return Form(
                        key: loginController.formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // App Logo / Title
                            const Icon(Icons.music_note_rounded, size: 64, color: AppTheme.primary),
                            const SizedBox(height: 12),
                            ShaderMask(
                              shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                              child: Text(
                                LoginStrings.appTitle,
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.displayLarge?.copyWith(color: Colors.white, fontSize: 36, letterSpacing: 2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              LoginStrings.appSubtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 48),

                            if (loginController.errorMessage.value != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  loginController.errorMessage.value!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Form Fields
                            if (loginController.isSignUp.value) ...[
                              TextFormField(
                                controller: loginController.nameController,
                                decoration: const InputDecoration(
                                  hintText: LoginStrings.fullName,
                                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return LoginStrings.enterNameError;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            TextFormField(
                              controller: loginController.emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: LoginStrings.emailAddress,
                                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                              ),
                              validator: (value) {
                                if (value == null || !value.contains('@')) {
                                  return LoginStrings.enterEmailError;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: loginController.passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: LoginStrings.password,
                                prefixIcon: Icon(Icons.lock_outlined, color: AppTheme.textSecondary),
                              ),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return LoginStrings.passwordLengthError;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Submit Button
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: authService.isLoading ? null : () => loginController.submit(context),
                                child: authService.isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(
                                        loginController.isSignUp.value
                                            ? LoginStrings.createAccount
                                            : LoginStrings.signIn,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Toggle Auth Mode
                            TextButton(
                              onPressed: () => loginController.toggleAuthMode(),
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                                  children: [
                                    TextSpan(
                                      text: loginController.isSignUp.value
                                          ? LoginStrings.alreadyHaveAccount
                                          : LoginStrings.newToApp,
                                      style: const TextStyle(color: AppTheme.textSecondary),
                                    ),
                                    TextSpan(
                                      text: loginController.isSignUp.value ? LoginStrings.signIn : LoginStrings.signUp,
                                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

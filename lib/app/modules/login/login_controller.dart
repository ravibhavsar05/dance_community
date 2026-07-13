import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dance_pulse/app/controllers/auth_controller.dart';
import 'package:dance_pulse/app/utils/app_strings.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';

class LoginController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  final RxBool isSignUp = false.obs;
  final RxnString errorMessage = RxnString();

  void toggleAuthMode() {
    isSignUp.value = !isSignUp.value;
    errorMessage.value = null;
  }

  Future<void> submit(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;
    
    errorMessage.value = null;
    final authController = Get.find<AuthController>();
    
    try {
      bool success;
      if (isSignUp.value) {
        success = await authController.signUpWithEmail(
          emailController.text.trim(),
          passwordController.text.trim(),
          nameController.text.trim(),
        );
        if (success && context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.mark_email_read_rounded, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    LoginStrings.verifyYourEmail,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Text(
                "${LoginStrings.verifyEmailMessagePrefix}${emailController.text.trim()}${LoginStrings.verifyEmailMessageSuffix}",
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    isSignUp.value = false;
                    errorMessage.value = null;
                    passwordController.clear();
                    nameController.clear();
                  },
                  child: const Text(LoginStrings.ok, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else {
        success = await authController.signInWithEmail(
          emailController.text.trim(),
          passwordController.text.trim(),
        );
      }
      
      if (!success) {
        errorMessage.value = LoginStrings.authFailed;
      }
    } catch (e) {
      if (e is AuthException) {
        errorMessage.value = e.message;
      } else if (e is PostgrestException) {
        errorMessage.value = e.message;
      } else {
        final errStr = e.toString();
        errorMessage.value = errStr.replaceAll("Exception: ", "").replaceAll(RegExp(r'\[.*?\]'), '').trim();
      }
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.onClose();
  }
}

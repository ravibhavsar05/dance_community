import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';
import 'package:dance_pulse/app/modules/profile/profile_screen.dart';

class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> children = [];
    final RegExp mentionRegExp = RegExp(r'@[a-zA-Z0-9_]+');
    
    int lastIndex = 0;
    for (final match in mentionRegExp.allMatches(text)) {
      if (match.start > lastIndex) {
        children.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: style,
        ));
      }
      
      final String mentionText = match.group(0)!;
      final String username = mentionText.substring(1); // remove @
      
      children.add(TextSpan(
        text: mentionText,
        style: mentionStyle ?? const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            try {
              final user = await SupabaseStore.instance.getProfileByUsername(username);
              if (user != null && context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: user.uid),
                  ),
                );
              } else {
                Get.snackbar(
                  "User Not Found",
                  "No dancer found with username @$username",
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                  colorText: Colors.white,
                );
              }
            } catch (e) {
              // ignore
            }
          },
      ));
      
      lastIndex = match.end;
    }
    
    if (lastIndex < text.length) {
      children.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }

    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(
        children: children,
        style: style ?? DefaultTextStyle.of(context).style,
      ),
    );
  }
}

import 'package:flutter/foundation.dart';

/// Common logging function that prints only in debug mode.
/// Automatically parses the stack trace to include the caller's file name and line number.
void appLog(Object? message) {
  if (kDebugMode) {
    final stackTrace = StackTrace.current;
    final frames = stackTrace.toString().split('\n');
    String callerFrame = '';
    
    // Find the first frame that is not from app_logger.dart
    for (final frame in frames) {
      if (frame.isEmpty) continue;
      if (!frame.contains('app_logger.dart') && frame.contains('.dart')) {
        callerFrame = frame;
        break;
      }
    }
    
    if (callerFrame.isEmpty && frames.length > 1) {
      callerFrame = frames[1];
    }

    String location = '';
    // Match package:url/file.dart:line:col or file:///path/file.dart:line:col
    final RegExp regExp = RegExp(r'((?:package:|file:///)[^\s)]+:\d+:\d+)');
    final match = regExp.firstMatch(callerFrame);
    if (match != null) {
      location = match.group(1) ?? '';
    } else {
      // Fallback: try matching anything that looks like file.dart:line
      final RegExp fallbackRegExp = RegExp(r'([a-zA-Z0-9_/.-]+\.dart:\d+)');
      final fallbackMatch = fallbackRegExp.firstMatch(callerFrame);
      if (fallbackMatch != null) {
        location = fallbackMatch.group(1) ?? '';
      } else {
        location = callerFrame.trim();
      }
    }

    // Print to console
    print('[APP LOG] [$location] $message');
  }
}

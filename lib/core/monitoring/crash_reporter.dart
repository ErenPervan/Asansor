import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized crash reporting service
class CrashReporter {
  /// Records a non-fatal error to Crashlytics
  static Future<void> recordError(
    dynamic error,
    StackTrace? stack, {
    String? context,
    bool isFatal = false,
  }) async {
    // Only report to Crashlytics in production
    if (kDebugMode) {
      debugPrint('[CrashReporter] (Ignored in debug): $error');
      if (stack != null) debugPrint(stack.toString());
      if (context != null) debugPrint('Context: $context');
      return;
    }

    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: context,
        fatal: isFatal,
      );
    } catch (e) {
      debugPrint('[CrashReporter] Failed to report error: $e');
    }
  }

  /// Logs an informational message to Crashlytics
  static Future<void> log(String message) async {
    if (kDebugMode) {
      debugPrint('[CrashReporter Log]: $message');
      return;
    }
    
    try {
      await FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      debugPrint('[CrashReporter] Failed to log message: $e');
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../exceptions/app_exception.dart';

/// Centralized utility for processing and displaying errors.
class ErrorHandler {
  ErrorHandler._();

  /// Processes an error and returns a user-friendly [AppException].
  static AppException handle(Object error, [StackTrace? stackTrace]) {
    debugPrint('ErrorHandler: Caught $error');
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }

    if (error is AppException) return error;

    if (error is supabase.PostgrestException) {
      return DatabaseException.fromPostgrest(error);
    }

    if (error is supabase.AuthException) {
      return AuthException(error.message);
    }

    if (error is TimeoutException) {
      return const NetworkException('İşlem zaman aşımına uğradı.');
    }

    // Generic fallback
    return DatabaseException(error.toString());
  }

  /// Shows a user-friendly snackbar for the given error.
  static void showSnackBar(BuildContext context, Object error) {
    final exception = handle(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(exception.message)),
          ],
        ),
        backgroundColor: const Color(0xFFB91C1C), // AppColors.primary
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

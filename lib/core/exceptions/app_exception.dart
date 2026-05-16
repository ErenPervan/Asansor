import 'package:supabase_flutter/supabase_flutter.dart';

/// Base class for all application-specific exceptions.
sealed class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Thrown when a network-related error occurs.
class NetworkException extends AppException {
  const NetworkException([String message = 'İnternet bağlantısı kurulamadı.'])
      : super(message, 'network_error');
}

/// Thrown during authentication failures.
class AuthException extends AppException {
  const AuthException([String message = 'Kimlik doğrulama hatası.'])
      : super(message, 'auth_error');
}

/// Thrown for database/Supabase related errors.
class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.code]);
  
  factory DatabaseException.fromPostgrest(PostgrestException e) {
    return DatabaseException(e.message, e.code);
  }
}

/// Thrown for user input or business logic validation errors.
class ValidationException extends AppException {
  const ValidationException(String message) : super(message, 'validation_error');
}

/// Thrown when a resource is not found.
class NotFoundException extends AppException {
  const NotFoundException([String message = 'Kaynak bulunamadı.'])
      : super(message, 'not_found');
}

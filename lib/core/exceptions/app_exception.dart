import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── AppException sealed hierarchy ────────────────────────────────────────────
//
// Every repository catch block maps to one of these concrete subclasses.
// The UI (via AsyncValue.error) can switch on the type for smart recovery UX:
//
//   error.whenOrNull(
//     error: (e, _) => switch (e) {
//       NetworkException() => const RetryButton(),
//       AppAuthException() => const SignOutButton(),
//       NotFoundException() => const NotFoundMessage(),
//       PermissionException() => const AccessDeniedMessage(),
//       ServerException()   => const ContactSupportMessage(),
//       AppException()      => ErrorText(e.message),
//     },
//   )
//
// ConflictException (conflict_exception.dart) stays separate because it
// carries domain-specific payload (remoteState) and is only used in the
// offline sync path.

/// Base class — never throw this directly; throw a concrete subclass.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The device has no internet connection or a DNS / TCP failure occurred.
///
/// Recovery: show a "Retry" button or wait for connectivity to return.
class NetworkException extends AppException {
  const NetworkException([super.message = 'İnternet bağlantısı yok.']);
}

/// The request timed out waiting for a response.
///
/// Recovery: offer a "Retry" button; back off and retry automatically.
class TimeoutAppException extends AppException {
  const TimeoutAppException([super.message = 'İstek zaman aşımına uğradı.']);
}

/// Supabase returned an authentication error (invalid credentials, expired
/// session, wrong password, etc.).
///
/// Recovery: redirect to the sign-in screen.
class AppAuthException extends AppException {
  const AppAuthException(super.message);
}

/// The requested resource was not found (HTTP 404 / PostgREST PGRST116).
///
/// Recovery: navigate back or show a "Not found" placeholder.
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// The caller does not have permission to perform the operation (HTTP 403,
/// PostgREST RLS violation).
///
/// Recovery: show an "Access denied" message; possibly sign out.
class PermissionException extends AppException {
  const PermissionException(
    super.message,
  );
}

/// The server returned an unexpected error (HTTP 5xx or an unrecognised
/// PostgREST error that is not a 404 or 403).
///
/// Recovery: show "Something went wrong, contact support."
class ServerException extends AppException {
  const ServerException(super.message);
}

// ── Mapping helpers ───────────────────────────────────────────────────────────

/// Maps a [PostgrestException] to the most appropriate [AppException] subclass.
///
/// PostgREST HTTP status codes:
///   400 → bad request / validation     → [ServerException]
///   401 → unauthorised                 → [AppAuthException]
///   403 → forbidden (RLS)              → [PermissionException]
///   404 → not found (PGRST116)         → [NotFoundException]
///   4xx → other client errors          → [ServerException]
///   5xx → server errors                → [ServerException]
AppException mapPostgrestException(PostgrestException e, [String? context]) {
  final prefix = context != null ? '$context: ' : '';
  final code = e.code ?? '';

  // PGRST116 — no rows returned when exactly one was expected (.single())
  if (code == 'PGRST116' || e.message.contains('JSON object requested')) {
    return NotFoundException('${prefix}Kayıt bulunamadı.');
  }

  // HTTP 401 — unauthenticated
  if (code == '401' || e.message.contains('JWT')) {
    return AppAuthException('${prefix}Oturum süresi doldu, lütfen tekrar giriş yapın.');
  }

  // HTTP 403 — RLS / permission denied
  if (code == '403' ||
      e.message.contains('permission denied') ||
      e.message.contains('row-level security') ||
      e.message.contains('RLS')) {
    return PermissionException('${prefix}Bu işlem için yetkiniz yok.');
  }

  // Default → server error
  return ServerException('$prefix${e.message}');
}

/// Converts any raw exception to a typed [AppException].
///
/// Call this from the generic `catch (e)` block in every repository method.
AppException mapUnknownException(Object e, [String? context]) {
  final prefix = context != null ? '$context: ' : '';

  if (e is AppException) return e; // already typed — pass through
  if (e is SocketException) {
    return NetworkException('${prefix}Sunucuya ulaşılamıyor.');
  }
  if (e is HandshakeException || e is TlsException) {
    return NetworkException('${prefix}Güvenli bağlantı kurulamadı.');
  }
  if (e is TimeoutException) {
    return TimeoutAppException('$prefixİstek zaman aşımına uğradı.');
  }
  if (e is AuthException) {
    return AppAuthException('$prefix${e.message}');
  }
  if (e is PostgrestException) {
    return mapPostgrestException(e, context);
  }

  debugPrint('[AppException] Unclassified error: $e');
  return ServerException('${prefix}Beklenmeyen bir hata oluştu.');
}

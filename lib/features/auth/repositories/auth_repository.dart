import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asansor/core/exceptions/app_exception.dart';
import 'package:asansor/core/services/notification_service.dart';

abstract interface class IAuthRepository {
  Future<User> signInWithEmail({
    required String email,
    required String password,
  });
  Future<void> signOut();
  User? getCurrentUser();
}

class AuthRepository implements IAuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Signs in with email and password.
  ///
  /// Returns the authenticated [User] on success.
  /// Throws a typed [AppException] subclass on failure.
  @override
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const ServerException(
          'Giriş başarılı ancak kullanıcı döndürülmedi.',
        );
      }

      // Register this device's FCM token with the user's profile so we can
      // send them targeted push notifications.
      await NotificationService.instance.saveTokenToSupabase(_client);

      return user;
    } on AppException {
      rethrow;
    } on AuthException catch (e) {
      throw AppAuthException('Giriş başarısız: ${e.message}');
    } catch (e) {
      throw mapUnknownException(e, 'signInWithEmail');
    }
  }

  /// Signs the current user out of the session.
  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AppException {
      rethrow;
    } on AuthException catch (e) {
      throw AppAuthException('Çıkış başarısız: ${e.message}');
    } catch (e) {
      throw mapUnknownException(e, 'signOut');
    }
  }

  /// Returns the currently authenticated [User], or `null` if not signed in.
  @override
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }
}

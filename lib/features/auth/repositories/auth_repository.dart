import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/notification_service.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Signs in with email and password.
  ///
  /// Returns the authenticated [User] on success.
  /// Throws a descriptive [Exception] on failure.
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
        throw Exception('Sign-in succeeded but no user was returned.');
      }

      // Register this device's FCM token with the user's profile so we can
      // send them targeted push notifications.
      await NotificationService.instance.saveTokenToSupabase(_client);

      return user;
    } on AuthException catch (e) {
      throw Exception('Sign-in failed: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error during sign-in: $e');
    }
  }

  /// Signs the current user out of the session.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw Exception('Sign-out failed: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error during sign-out: $e');
    }
  }

  /// Returns the currently authenticated [User], or `null` if not signed in.
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Lightweight role lookup — fetches only the `role` column from the
  /// `profiles` table for [userId].
  ///
  /// Returns `null` when the profile row does not exist yet (e.g. immediately
  /// after first sign-up before the DB trigger fires).
  /// Never throws — failures are swallowed and return `null` so callers can
  /// degrade gracefully.
  Future<String?> fetchProfileRole(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return response?['role'] as String?;
    } catch (_) {
      return null;
    }
  }
}

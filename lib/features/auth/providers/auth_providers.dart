import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../repositories/auth_repository.dart';

// ── Repository ──────────────────────────────────────────────────────────────

/// Provides the [AuthRepository] backed by the live Supabase client.
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

// ── Session Stream ───────────────────────────────────────────────────────────

/// Emits the current [User] whenever the auth state changes (sign-in / sign-out).
///
/// Returns `null` when the user is not authenticated.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange.map(
    (event) => event.session?.user,
  );
});

// ── Auth Controller ──────────────────────────────────────────────────────────

/// Manages sign-in and sign-out operations.
///
/// State holds the current [User] (or `null` if signed out),
/// with [AsyncLoading] during transitions and [AsyncError] on failure.
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    // Resolve the initial user synchronously from the current session.
    return ref.read(authRepositoryProvider).getCurrentUser();
  }

  /// Signs in with [email] and [password].
  ///
  /// On success, state becomes `AsyncData<User>`.
  /// On failure, state becomes `AsyncError` with a user-friendly message.
  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: password);
    });
  }

  /// Signs out the current user and resets state to `AsyncData(null)`.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      return null;
    });
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);

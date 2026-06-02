import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums/app_enums.dart';
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
  return ref
      .watch(supabaseClientProvider)
      .auth
      .onAuthStateChange
      .map((event) => event.session?.user);
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

// ── App Auth State Machine ───────────────────────────────────────────────────

enum AuthStatus {
  initial,
  unauthenticated,
  profileLoading,
  authorized,
  error,
}

class AuthStateModel {
  final AuthStatus status;
  final User? user;
  final UserRole? role;
  final String? elevatorId;
  final String? errorMessage;

  const AuthStateModel({
    required this.status,
    this.user,
    this.role,
    this.elevatorId,
    this.errorMessage,
  });
}

// We cannot import profile_providers here to avoid circular dependency.
// So we will define this in a new file, or we can just keep the model here and 
// define the provider in app_router.dart where it can import everything.

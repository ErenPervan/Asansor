import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/app_enums.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';

// ── Router role notifier removed (now handled by auth_providers.dart) ──

// ── Repository ────────────────────────────────────────────────────────────────

final profileRepositoryProvider = Provider<IProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

// ── Current user profile ──────────────────────────────────────────────────────

/// Fetches the [ProfileModel] of the signed-in user.
///
/// Automatically refetches when [authControllerProvider] emits a new user.
/// As a side-effect it updates [routerRoleNotifier] so GoRouter can enforce
/// admin-only route guards without async redirect.
final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;

  if (user == null) {
    return null;
  }

  final repo = ref.read(profileRepositoryProvider);
  final profile = await repo.getProfile(user.id);

  return profile;
});

/// Exposes the current user's role (`UserRole`).
///
/// Use this provider in UI to conditionally show admin controls:
/// ```dart
/// final role = ref.watch(roleProvider);
/// if (role == UserRole.admin) ...
/// ```
final roleProvider = Provider<UserRole?>(
  (ref) => ref.watch(currentProfileProvider).valueOrNull?.role,
);

// ── User list providers ───────────────────────────────────────────────────────

/// Fetches all profiles (used in the "Tüm Kullanıcılar" tab).
final allProfilesProvider = FutureProvider<List<ProfileModel>>((ref) {
  return ref.watch(profileRepositoryProvider).getAllProfiles();
});

/// Fetches profiles filtered by role.
///
/// Usage: `ref.watch(profilesByRoleProvider('technician'))`
final profilesByRoleProvider =
    FutureProvider.family<List<ProfileModel>, UserRole>((ref, role) {
      return ref
          .watch(profileRepositoryProvider)
          .getProfilesByRole(role.dbValue);
    });

// ── Mutation notifier ─────────────────────────────────────────────────────────

/// Handles role changes and customer–elevator assignments.
///
/// Usage:
/// ```dart
/// ref.read(profileUpdateControllerProvider.notifier).updateRole(id, 'admin');
/// ```
class ProfileUpdateController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateRole(String userId, UserRole newRole) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .updateRole(userId, newRole.dbValue);
      _invalidateAllLists(ref);
      // Refresh the current user's own profile in case they edited themselves.
      ref.invalidate(currentProfileProvider);
    });
  }

  Future<void> updateCustomerElevator(String userId, String? elevatorId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .updateCustomerElevator(userId, elevatorId);
      _invalidateAllLists(ref);
      // Re-fetch the current user's own profile so the router notifier picks up
      // the new elevatorId and redirects the customer instantly (without
      // requiring a sign-out / sign-in cycle).
      ref.invalidate(currentProfileProvider);
    });
  }
}

final profileUpdateControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfileUpdateController, void>(
      ProfileUpdateController.new,
    );

// ── Helpers ───────────────────────────────────────────────────────────────────

void _invalidateAllLists(Ref ref) {
  ref.invalidate(allProfilesProvider);
  ref.invalidate(profilesByRoleProvider(UserRole.admin));
  ref.invalidate(profilesByRoleProvider(UserRole.technician));
  ref.invalidate(profilesByRoleProvider(UserRole.customer));
}

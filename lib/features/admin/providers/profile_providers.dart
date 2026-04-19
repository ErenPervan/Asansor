import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';

// ── Router role notifier ──────────────────────────────────────────────────────
//
// A lightweight ChangeNotifier that sits outside Riverpod and can be referenced
// by GoRouter as a refreshListenable.  Updated by [currentProfileProvider]
// whenever the current user's profile loads or the session changes.

class RouterRoleNotifier extends ChangeNotifier {
  String? _role;
  String? _elevatorId;

  /// The currently cached role (`'admin'` | `'technician'` | `'customer'` | `null`).
  ///
  /// `null` means either the user is not signed in, or the profile is still loading.
  String? get role => _role;

  /// For `customer` role: the elevator UUID linked to this user's profile.
  /// `null` when the role is not `'customer'`, the profile is loading,
  /// or the customer has no elevator assigned yet.
  String? get elevatorId => _elevatorId;

  void _update(String? role, String? elevatorId) {
    if (_role == role && _elevatorId == elevatorId) return;
    _role = role;
    _elevatorId = elevatorId;
    notifyListeners();
  }
}

/// Singleton accessible from `app_router.dart` without going through Riverpod.
final routerRoleNotifier = RouterRoleNotifier();

// ── Repository ────────────────────────────────────────────────────────────────

final profileRepositoryProvider = Provider<ProfileRepository>(
  (_) => ProfileRepository(Supabase.instance.client),
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
    routerRoleNotifier._update(null, null);
    return null;
  }

  final repo = ref.read(profileRepositoryProvider);
  final profile = await repo.getProfile(user.id);

  // Propagate role + elevatorId to the router so it can enforce both the
  // admin guard and the customer-scoped elevator redirect synchronously.
  routerRoleNotifier._update(
    profile?.role,
    profile?.isCustomer == true ? profile?.elevatorId : null,
  );

  return profile;
});

/// Exposes the current user's role string (`'admin'` | `'technician'` |
/// `'customer'` | `null`).
///
/// Use this provider in UI to conditionally show admin controls:
/// ```dart
/// final role = ref.watch(roleProvider);
/// if (role == 'admin') ...
/// ```
final roleProvider = Provider<String?>(
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
    FutureProvider.family<List<ProfileModel>, String>((ref, role) {
  return ref.watch(profileRepositoryProvider).getProfilesByRole(role);
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

  Future<void> updateRole(String userId, String newRole) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(profileRepositoryProvider).updateRole(userId, newRole);
      _invalidateAllLists(ref);
      // Refresh the current user's own profile in case they edited themselves.
      ref.invalidate(currentProfileProvider);
    });
  }

  Future<void> updateCustomerElevator(
    String userId,
    String? elevatorId,
  ) async {
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
  ref.invalidate(profilesByRoleProvider('admin'));
  ref.invalidate(profilesByRoleProvider('technician'));
  ref.invalidate(profilesByRoleProvider('customer'));
}

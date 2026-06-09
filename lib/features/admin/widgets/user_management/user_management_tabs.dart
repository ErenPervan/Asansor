import 'package:asansor/core/enums/app_capability.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asansor/features/admin/widgets/user_management/user_management_grid.dart';
import 'package:asansor/features/admin/widgets/user_management/user_management_shared.dart';
import 'package:asansor/features/admin/widgets/user_management/user_management_utils.dart';

class UserListTab extends ConsumerWidget {
  const UserListTab({super.key, required this.role, required this.query});

  final UserRole? role;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final canManageUsers = profile?.can(AppCapability.manageUsers) ?? false;
    final profilesAsync = role == null
        ? ref.watch(allProfilesProvider)
        : ref.watch(profilesByRoleProvider(role!));

    return profilesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: LoadingState(count: 4),
      ),
      error: (e, _) => ErrorPane(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => role == null
            ? ref.invalidate(allProfilesProvider)
            : ref.invalidate(profilesByRoleProvider(role!)),
      ),
      data: (profiles) {
        final filtered = filterProfiles(profiles, query);
        if (filtered.isEmpty) {
          return EmptyPane(
            icon: role == UserRole.technician
                ? Icons.engineering_rounded
                : Icons.groups_rounded,
            message: query.isEmpty
                ? (role == UserRole.technician
                    ? 'Henüz teknisyen kaydı yok.'
                    : 'Henüz kullanıcı kaydı yok.')
                : 'Aramanıza uygun kullanıcı bulunamadı.',
          );
        }

        return UserManagementGrid(
          profiles: filtered,
          canManageUsers: canManageUsers,
          onRefresh: () async {
            if (role == null) {
              final _ = await ref.refresh(allProfilesProvider.future);
            } else {
              final _ = await ref.refresh(profilesByRoleProvider(role!).future);
            }
          },
        );
      },
    );
  }
}

class CustomerTab extends ConsumerWidget {
  const CustomerTab({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final canManageUsers = profile?.can(AppCapability.manageUsers) ?? false;
    final canAssignElevators =
        profile?.can(AppCapability.manageElevators) ?? false;
    final customersAsync = ref.watch(profilesByRoleProvider(UserRole.customer));
    final elevatorsAsync = ref.watch(elevatorsProvider);

    return customersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: LoadingState(count: 4),
      ),
      error: (e, _) => ErrorPane(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () =>
            ref.invalidate(profilesByRoleProvider(UserRole.customer)),
      ),
      data: (customers) {
        final elevators = elevatorsAsync.valueOrNull ?? [];
        final filtered = filterProfiles(customers, query, elevators);
        if (filtered.isEmpty) {
          return EmptyPane(
            icon: Icons.apartment_rounded,
            message: query.isEmpty
                ? 'Henüz müşteri kaydı yok.'
                : 'Aramanıza uygun müşteri bulunamadı.',
          );
        }

        return UserManagementGrid(
          profiles: filtered,
          elevators: elevators,
          canManageUsers: canManageUsers,
          canAssignElevators: canAssignElevators,
          onRefresh: () async {
            await Future.wait([
              ref.refresh(profilesByRoleProvider(UserRole.customer).future),
              ref.refresh(elevatorsProvider.future),
            ]);
          },
        );
      },
    );
  }
}

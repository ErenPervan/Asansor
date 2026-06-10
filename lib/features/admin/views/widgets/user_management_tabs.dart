import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/enums/app_capability.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/admin/views/widgets/user_management_helpers.dart';
import 'package:asansor/features/admin/views/widgets/user_management_sheets.dart';

class UserManagementListTab extends ConsumerWidget {
  const UserManagementListTab({
    super.key,
    required this.role,
    required this.query,
  });

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

        return _ProfileGrid(
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

class UserManagementCustomerTab extends ConsumerWidget {
  const UserManagementCustomerTab({super.key, required this.query});

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

        return _ProfileGrid(
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

class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({
    required this.profiles,
    required this.canManageUsers,
    required this.onRefresh,
    this.elevators,
    this.canAssignElevators = false,
  });

  final List<ProfileModel> profiles;
  final List<ElevatorModel>? elevators;
  final bool canManageUsers;
  final bool canAssignElevators;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1060
              ? 3
              : constraints.maxWidth >= 680
              ? 2
              : 1;

          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: columns == 1 ? 1.7 : 1.25,
              mainAxisExtent: columns == 1 ? 304 : 278,
            ),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return _ProfileCard(
                profile: profile,
                elevators: elevators,
                canManageUsers: canManageUsers,
                onEditRole: canManageUsers
                    ? () => showEditRoleSheet(context, profile)
                    : null,
                onAssignElevator:
                    canAssignElevators && profile.role == UserRole.customer
                    ? () => showAssignElevatorSheet(
                        context,
                        profile,
                        elevators ?? const [],
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.canManageUsers,
    this.elevators,
    this.onEditRole,
    this.onAssignElevator,
  });

  final ProfileModel profile;
  final bool canManageUsers;
  final List<ElevatorModel>? elevators;
  final VoidCallback? onEditRole;
  final VoidCallback? onAssignElevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final role = roleStyle(context, profile.role);
    final elevator = linkedElevator(profile, elevators);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: panelLine),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: role.avatarBg,
                child: Text(
                  profile.initials,
                  style: textTheme.titleMedium?.copyWith(
                    color: role.avatarFg,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profile.email != null && profile.email!.isNotEmpty)
                      Text(
                        profile.email!,
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              _RoleBadge(role: profile.role),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: role.icon,
                label: roleLabel(profile.role),
                color: role.fg,
              ),
              if (profile.phone != null && profile.phone!.isNotEmpty)
                _InfoChip(
                  icon: Icons.phone_rounded,
                  label: profile.phone!,
                  color: colors.onSurfaceVariant,
                ),
              if (profile.role == UserRole.customer)
                _InfoChip(
                  icon: Icons.elevator_rounded,
                  label: elevator?.buildingName ?? 'Asansör atanmamış',
                  color: elevator == null ? colors.warning : colors.primary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: AppSpacing.lg, color: colors.outlineVariant),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  shortId(profile.id),
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.outline,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onAssignElevator != null)
                TextButton.icon(
                  onPressed: onAssignElevator,
                  icon: const Icon(Icons.link_rounded, size: 17),
                  label: const Text('Asansör Ata'),
                ),
              if (onEditRole != null)
                TextButton.icon(
                  onPressed: onEditRole,
                  icon: const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 17,
                  ),
                  label: const Text('Rol'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final style = roleStyle(context, role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        roleLabel(role),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: style.fg,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

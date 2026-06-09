import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:flutter/material.dart';

import 'package:asansor/features/admin/widgets/user_management/user_elevator_sheet.dart';
import 'package:asansor/features/admin/widgets/user_management/user_management_shared.dart';
import 'package:asansor/features/admin/widgets/user_management/user_management_utils.dart';
import 'package:asansor/features/admin/widgets/user_management/user_role_sheet.dart';

class UserManagementGrid extends StatelessWidget {
  const UserManagementGrid({
    super.key,
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
    final role = getRoleStyle(context, profile.role);
    final elevator = getLinkedElevator(profile, elevators);

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
                label: getRoleLabel(profile.role),
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
                  getShortId(profile.id),
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
                  icon:
                      const Icon(Icons.admin_panel_settings_rounded, size: 17),
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
    final style = getRoleStyle(context, role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        getRoleLabel(role),
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

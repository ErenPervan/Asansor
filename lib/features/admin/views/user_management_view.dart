import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/loading_state.dart';

import '../../elevator/models/elevator_model.dart';

import '../../elevator/providers/elevator_providers.dart';

import '../models/profile_model.dart';

import '../providers/profile_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
// ── Role helpers ──────────────────────────────────────────────────────────────

import '../../../core/enums/app_enums.dart';
import '../../../core/enums/app_capability.dart';

_RoleStyle _roleStyle(BuildContext context, UserRole role) {
  final colors = AppThemeColors.of(context);
  switch (role) {
    case UserRole.admin:
      return _RoleStyle(
        bg: colors.primary,
        fg: colors.surface,
        avatarBg: colors.primaryDark,
        avatarFg: colors.surface,
        icon: Icons.admin_panel_settings_outlined,
      );
    case UserRole.customer:
      return _RoleStyle(
        bg: colors.successContainer,
        fg: colors.success,
        avatarBg: colors.success, // keep original brand color or colors.success
        avatarFg: colors.surface,
        icon: Icons.person_outline,
      );
    default: // technician
      return _RoleStyle(
        bg: colors.primary.withValues(alpha: 0.15), // or another semantic color
        fg: colors.primary,
        avatarBg: colors.primary.withValues(alpha: 0.80),
        avatarFg: colors.surface,
        icon: Icons.engineering_outlined,
      );
  }
}

class _RoleStyle {
  const _RoleStyle({
    required this.bg,
    required this.fg,
    required this.avatarBg,
    required this.avatarFg,
    required this.icon,
  });
  final Color bg;
  final Color fg;
  final Color avatarBg;
  final Color avatarFg;
  final IconData icon;
}

// ── UserManagementView ────────────────────────────────────────────────────────

class UserManagementView extends ConsumerStatefulWidget {
  const UserManagementView({super.key});

  @override
  ConsumerState<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends ConsumerState<UserManagementView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(allProfilesProvider);
    ref.invalidate(profilesByRoleProvider(UserRole.technician));
    ref.invalidate(profilesByRoleProvider(UserRole.customer));
    ref.invalidate(profilesByRoleProvider(UserRole.admin));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.primary,
        foregroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'Kullanıcı Yönetimi',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.0,
            color: colors.surface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Yenile',
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: colors.surface,
          indicatorWeight: 3,
          labelColor: colors.surface,
          unselectedLabelColor: colors.surface.withValues(alpha: 0.6),
          labelStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.engineering_outlined, size: 18),
              text: 'Teknisyenler',
            ),
            Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Müşteriler'),
            Tab(
              icon: Icon(Icons.groups_outlined, size: 18),
              text: 'Tüm Kullanıcılar',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _UserListTab(role: UserRole.technician),
          _CustomerTab(),
          _UserListTab(role: null),
        ],
      ),
    );
  }
}

// ── Generic user list tab (Technicians / All Users) ───────────────────────────

class _UserListTab extends ConsumerWidget {
  const _UserListTab({required this.role});

  /// Filter role — `null` means fetch all users.
  final UserRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final canManageUsers = profile?.can(AppCapability.manageUsers) ?? false;
    final profilesAsync = role == null
        ? ref.watch(allProfilesProvider)
        : ref.watch(profilesByRoleProvider(role!));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: profilesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LoadingState(count: 4),
        ),
        error: (e, _) => _ErrorPane(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => role == null
              ? ref.invalidate(allProfilesProvider)
              : ref.invalidate(profilesByRoleProvider(role!)),
        ),
        data: (profiles) {
          if (profiles.isEmpty) {
            return _EmptyPane(
              icon: role == UserRole.technician
                  ? Icons.engineering_outlined
                  : Icons.groups_outlined,
              message: role == UserRole.technician
                  ? 'Henüz teknisyen kaydı yok.'
                  : 'Henüz kullanıcı kaydı yok.',
            );
          }
          return RefreshIndicator(
            color: colors.primary,
            onRefresh: () async => role == null
                ? ref.invalidate(allProfilesProvider)
                : ref.invalidate(profilesByRoleProvider(role!)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 600) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: (profiles.length / 2).ceil(),
                    itemBuilder: (context, i) {
                      final idx1 = i * 2;
                      final idx2 = i * 2 + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ProfileCard(
                                profile: profiles[idx1],
                                canManageUsers: canManageUsers,
                                onEditRole: () =>
                                    _showEditRoleSheet(context, profiles[idx1]),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: idx2 < profiles.length
                                  ? _ProfileCard(
                                      profile: profiles[idx2],
                                      canManageUsers: canManageUsers,
                                      onEditRole: () => _showEditRoleSheet(
                                        context,
                                        profiles[idx2],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: profiles.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ProfileCard(
                    profile: profiles[i],
                    canManageUsers: canManageUsers,
                    onEditRole: () => _showEditRoleSheet(context, profiles[i]),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Customer tab (includes elevator assignment) ───────────────────────────────

class _CustomerTab extends ConsumerWidget {
  const _CustomerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final canManageUsers = profile?.can(AppCapability.manageUsers) ?? false;
    final canAssignElevators =
        profile?.can(AppCapability.manageElevators) ?? false;
    final profilesAsync = ref.watch(profilesByRoleProvider(UserRole.customer));
    final elevatorsAsync = ref.watch(elevatorsProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: profilesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LoadingState(count: 4),
        ),
        error: (e, _) => _ErrorPane(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () =>
              ref.invalidate(profilesByRoleProvider(UserRole.customer)),
        ),
        data: (customers) {
          if (customers.isEmpty) {
            return const _EmptyPane(
              icon: Icons.person_search_outlined,
              message: 'Henüz müşteri kaydı yok.',
            );
          }
          final elevators = elevatorsAsync.valueOrNull ?? [];
          return RefreshIndicator(
            color: colors.primary,
            onRefresh: () async {
              ref.invalidate(profilesByRoleProvider(UserRole.customer));
              ref.invalidate(elevatorsProvider);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 600) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: (customers.length / 2).ceil(),
                    itemBuilder: (context, i) {
                      final idx1 = i * 2;
                      final idx2 = i * 2 + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ProfileCard(
                                profile: customers[idx1],
                                canManageUsers: canManageUsers,
                                elevators: elevators,
                                onEditRole: () => _showEditRoleSheet(
                                  context,
                                  customers[idx1],
                                ),
                                onAssignElevator: canAssignElevators
                                    ? () => _showAssignElevatorSheet(
                                        context,
                                        customers[idx1],
                                        elevators,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: idx2 < customers.length
                                  ? _ProfileCard(
                                      profile: customers[idx2],
                                      canManageUsers: canManageUsers,
                                      elevators: elevators,
                                      onEditRole: () => _showEditRoleSheet(
                                        context,
                                        customers[idx2],
                                      ),
                                      onAssignElevator: canAssignElevators
                                          ? () => _showAssignElevatorSheet(
                                              context,
                                              customers[idx2],
                                              elevators,
                                            )
                                          : null,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: customers.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ProfileCard(
                    profile: customers[i],
                    canManageUsers: canManageUsers,
                    elevators: elevators,
                    onEditRole: () => _showEditRoleSheet(context, customers[i]),
                    onAssignElevator: canAssignElevators
                        ? () => _showAssignElevatorSheet(
                            context,
                            customers[i],
                            elevators,
                          )
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.canManageUsers,
    this.elevators,
    required this.onEditRole,
    this.onAssignElevator,
  });

  final ProfileModel profile;
  final bool canManageUsers;
  final List<ElevatorModel>? elevators;
  final VoidCallback onEditRole;
  final VoidCallback? onAssignElevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final style = _roleStyle(context, profile.role);

    ElevatorModel? linkedElevator;
    if (profile.elevatorId != null && elevators != null) {
      try {
        linkedElevator = elevators!.firstWhere(
          (e) => e.id == profile.elevatorId,
        );
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: avatar + identity + role badge ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: style.avatarBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  profile.initials,
                  style: textTheme.titleMedium?.copyWith(
                    color: style.avatarFg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profile.email != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.email!,
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            profile.phone!,
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 12, color: style.fg),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      profile.roleTr,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: style.fg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Customer: elevator assignment section ────────────────────
          if (profile.isCustomer) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.elevator_outlined,
                  size: 14,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: linkedElevator != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              linkedElevator.buildingName,
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (linkedElevator.address != null)
                              Text(
                                linkedElevator.address!,
                                style: textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  color: colors.outline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        )
                      : Text(
                          'Asansör bağlı değil',
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                ),
                if (onAssignElevator != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: onAssignElevator,
                    icon: Icon(
                      linkedElevator != null
                          ? Icons.swap_horiz_outlined
                          : Icons.add_link_outlined,
                      size: 14,
                    ),
                    label: Text(
                      linkedElevator != null ? 'Değiştir' : 'Ata',
                      style: textTheme.labelSmall,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // ── Admin action row ─────────────────────────────────────────
          if (canManageUsers) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEditRole,
                  icon: const Icon(Icons.manage_accounts_outlined, size: 14),
                  label: Text(
                    'Rol Değiştir',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Edit Role bottom sheet ────────────────────────────────────────────────────

void _showEditRoleSheet(BuildContext context, ProfileModel profile) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (_) => _EditRoleSheet(profile: profile),
  );
}

class _EditRoleSheet extends ConsumerStatefulWidget {
  const _EditRoleSheet({required this.profile});
  final ProfileModel profile;

  @override
  ConsumerState<_EditRoleSheet> createState() => _EditRoleSheetState();
}

class _EditRoleSheetState extends ConsumerState<_EditRoleSheet> {
  late UserRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.profile.role;
  }

  Future<void> _save() async {
    if (_selectedRole == widget.profile.role) {
      Navigator.of(context).pop();
      return;
    }
    await ref
        .read(profileUpdateControllerProvider.notifier)
        .updateRole(widget.profile.id, _selectedRole);

    final state = ref.read(profileUpdateControllerProvider);
    if (!mounted) return;

    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppThemeColors.of(context).error,
        ),
      );
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.profile.displayName} artık '
            '${_selectedRole.name} olarak güncellendi.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppThemeColors.of(context).success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isLoading = ref.watch(profileUpdateControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.manage_accounts_outlined,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rol Değiştir',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          widget.profile.displayName,
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.outline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Role options
              ...[
                (
                  UserRole.admin,
                  'Admin',
                  Icons.admin_panel_settings_outlined,
                  'Tüm yetkilere sahip yönetici',
                ),
                (
                  UserRole.technician,
                  'Teknisyen',
                  Icons.engineering_outlined,
                  'Asansör bakım ve arıza yönetimi',
                ),
                (
                  UserRole.customer,
                  'Müşteri',
                  Icons.person_outline,
                  'Bina sakini / asansör kullanıcısı',
                ),
              ].map((item) {
                final (roleValue, roleLabel, roleIcon, roleSubtitle) = item;
                final style = _roleStyle(context, roleValue);
                final isSelected = _selectedRole == roleValue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: isLoading
                        ? null
                        : () => setState(() => _selectedRole = roleValue),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? style.bg.withValues(alpha: 0.18)
                            : colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? style.fg.withValues(alpha: 0.5)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? style.bg
                                  : colors.outlineVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              roleIcon,
                              size: 18,
                              color: isSelected ? style.fg : colors.surface,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  roleLabel,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? style.fg
                                        : colors.onSurface,
                                  ),
                                ),
                                Text(
                                  roleSubtitle,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: style.fg, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 4),
              FilledButton(
                onPressed: isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.surface,
                        ),
                      )
                    : Text(
                        'Kaydet',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.surface,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Assign Elevator bottom sheet (customers) ──────────────────────────────────

void _showAssignElevatorSheet(
  BuildContext context,
  ProfileModel customer,
  List<ElevatorModel> elevators,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        _AssignElevatorSheet(customer: customer, elevators: elevators),
  );
}

class _AssignElevatorSheet extends ConsumerStatefulWidget {
  const _AssignElevatorSheet({required this.customer, required this.elevators});
  final ProfileModel customer;
  final List<ElevatorModel> elevators;

  @override
  ConsumerState<_AssignElevatorSheet> createState() =>
      _AssignElevatorSheetState();
}

class _AssignElevatorSheetState extends ConsumerState<_AssignElevatorSheet> {
  String? _selectedElevatorId;

  @override
  void initState() {
    super.initState();
    _selectedElevatorId = widget.customer.elevatorId;
  }

  Future<void> _save() async {
    if (_selectedElevatorId == widget.customer.elevatorId) {
      Navigator.of(context).pop();
      return;
    }
    await ref
        .read(profileUpdateControllerProvider.notifier)
        .updateCustomerElevator(widget.customer.id, _selectedElevatorId);

    final state = ref.read(profileUpdateControllerProvider);
    if (!mounted) return;

    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppThemeColors.of(context).error,
        ),
      );
    } else {
      Navigator.of(context).pop();
      final elevator = _selectedElevatorId == null
          ? null
          : widget.elevators
                .where((e) => e.id == _selectedElevatorId)
                .firstOrNull;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            elevator != null
                ? '${widget.customer.displayName} → ${elevator.buildingName} atandı.'
                : '${widget.customer.displayName} asansör bağlantısı kaldırıldı.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isLoading = ref.watch(profileUpdateControllerProvider).isLoading;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Title
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.elevator_outlined, color: colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asansör Ata',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          widget.customer.displayName,
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.outline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Elevator list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // "Bağlantıyı Kaldır" option
                    _ElevatorOption(
                      label: 'Bağlantıyı Kaldır',
                      subtitle: 'Müşteriyi asansörden ayır',
                      icon: Icons.link_off_outlined,
                      isSelected: _selectedElevatorId == null,
                      isDestructive: true,
                      onTap: isLoading
                          ? null
                          : () => setState(() => _selectedElevatorId = null),
                    ),
                    const SizedBox(height: 6),
                    ...widget.elevators.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _ElevatorOption(
                          label: e.buildingName,
                          subtitle: e.address ?? 'Adres belirtilmemiş',
                          icon: Icons.elevator_outlined,
                          isSelected: _selectedElevatorId == e.id,
                          onTap: isLoading
                              ? null
                              : () =>
                                    setState(() => _selectedElevatorId = e.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // Save button (pinned at bottom)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: FilledButton(
                    onPressed: isLoading ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.surface,
                            ),
                          )
                        : Text(
                            'Kaydet',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.surface,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ElevatorOption extends StatelessWidget {
  const _ElevatorOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    this.isDestructive = false,
    this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isDestructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final accentColor = isDestructive ? colors.error : colors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? accentColor : colors.outline,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? accentColor : colors.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: accentColor, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Shared empty / error states ───────────────────────────────────────────────

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colors.outlineVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.titleSmall?.copyWith(
                color: colors.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: colors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: FilledButton.styleFrom(backgroundColor: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

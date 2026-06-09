import 'package:asansor/core/enums/app_capability.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _panelLine = Color(0xFFE1E8F0);

class UserManagementView extends ConsumerStatefulWidget {
  const UserManagementView({super.key});

  @override
  ConsumerState<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends ConsumerState<UserManagementView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next != _query) setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(allProfilesProvider);
    ref.invalidate(profilesByRoleProvider(UserRole.technician));
    ref.invalidate(profilesByRoleProvider(UserRole.customer));
    ref.invalidate(profilesByRoleProvider(UserRole.admin));
    ref.invalidate(elevatorsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Icon(Icons.manage_accounts_rounded, color: colors.primary),
            const SizedBox(width: 10),
            Text(
              'Kullanıcı Yönetimi',
              style: textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _HeaderSection(
            searchController: _searchController,
            tabController: _tabs,
            onRefresh: _refresh,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _UserListTab(role: UserRole.technician, query: _query),
                _CustomerTab(query: _query),
                _UserListTab(role: null, query: _query),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.searchController,
    required this.tabController,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final TabController tabController;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: const Border(bottom: BorderSide(color: _panelLine)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  return Flex(
                    direction: compact ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: compact
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: compact ? 0 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kullanıcı Yönetimi',
                              style: textTheme.headlineSmall?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Platform erişimlerini, operasyonel rolleri ve müşteri asansör bağlantılarını yönetin.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (compact) const SizedBox(height: AppSpacing.md),
                      _RefreshButton(onRefresh: onRefresh),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _SearchBox(controller: searchController),
              const SizedBox(height: AppSpacing.md),
              TabBar(
                controller: tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: colors.primary,
                indicatorWeight: 3,
                labelColor: colors.primary,
                unselectedLabelColor: colors.onSurfaceVariant,
                labelStyle: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.engineering_rounded, size: 18),
                    text: 'Teknisyenler',
                  ),
                  Tab(
                    icon: Icon(Icons.apartment_rounded, size: 18),
                    text: 'Müşteriler',
                  ),
                  Tab(
                    icon: Icon(Icons.groups_rounded, size: 18),
                    text: 'Tüm Kullanıcılar',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return OutlinedButton.icon(
      onPressed: onRefresh,
      icon: const Icon(Icons.refresh_rounded, size: 19),
      label: const Text('Yenile'),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        backgroundColor: colors.surface,
        side: const BorderSide(color: _panelLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Kullanıcı ara: isim, e-posta, telefon veya asansör',
        prefixIcon: Icon(Icons.search_rounded, color: colors.outline),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: controller.clear,
              ),
        filled: true,
        fillColor: colors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    );
  }
}

class _UserListTab extends ConsumerWidget {
  const _UserListTab({required this.role, required this.query});

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
      error: (e, _) => _ErrorPane(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => role == null
            ? ref.invalidate(allProfilesProvider)
            : ref.invalidate(profilesByRoleProvider(role!)),
      ),
      data: (profiles) {
        final filtered = _filterProfiles(profiles, query);
        if (filtered.isEmpty) {
          return _EmptyPane(
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

class _CustomerTab extends ConsumerWidget {
  const _CustomerTab({required this.query});

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
      error: (e, _) => _ErrorPane(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () =>
            ref.invalidate(profilesByRoleProvider(UserRole.customer)),
      ),
      data: (customers) {
        final elevators = elevatorsAsync.valueOrNull ?? [];
        final filtered = _filterProfiles(customers, query, elevators);
        if (filtered.isEmpty) {
          return _EmptyPane(
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
                    ? () => _showEditRoleSheet(context, profile)
                    : null,
                onAssignElevator:
                    canAssignElevators && profile.role == UserRole.customer
                    ? () => _showAssignElevatorSheet(
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
    final role = _roleStyle(context, profile.role);
    final elevator = _linkedElevator(profile, elevators);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelLine),
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
                label: _roleLabel(profile.role),
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
                  _shortId(profile.id),
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
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 17),
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
    final style = _roleStyle(context, role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _roleLabel(role),
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

void _showEditRoleSheet(BuildContext context, ProfileModel profile) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
      _showSheetSnack(
        context,
        state.error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
      return;
    }

    Navigator.of(context).pop();
    _showSheetSnack(
      context,
      '${widget.profile.displayName} rolü ${_roleLabel(_selectedRole)} olarak güncellendi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isLoading = ref.watch(profileUpdateControllerProvider).isLoading;

    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Rol Değiştir',
            subtitle: widget.profile.displayName,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final option in UserRole.values) ...[
            _RoleOption(
              role: option,
              selected: _selectedRole == option,
              onTap: isLoading ? null : () => setState(() => _selectedRole = option),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: isLoading ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : Text(
                    'Kaydet',
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final style = _roleStyle(context, role);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? style.fg.withValues(alpha: 0.10) : colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? style.fg.withValues(alpha: 0.38) : _panelLine,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? style.fg : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                style.icon,
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roleLabel(role),
                    style: textTheme.titleSmall?.copyWith(
                      color: selected ? style.fg : colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _roleDescription(role),
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: style.fg),
          ],
        ),
      ),
    );
  }
}

void _showAssignElevatorSheet(
  BuildContext context,
  ProfileModel customer,
  List<ElevatorModel> elevators,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
      _showSheetSnack(
        context,
        state.error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
      return;
    }

    final elevator = _elevatorById(widget.elevators, _selectedElevatorId);
    Navigator.of(context).pop();
    _showSheetSnack(
      context,
      elevator == null
          ? '${widget.customer.displayName} asansör bağlantısı kaldırıldı.'
          : '${widget.customer.displayName} → ${elevator.buildingName} atandı.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isLoading = ref.watch(profileUpdateControllerProvider).isLoading;

    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(
            icon: Icons.elevator_rounded,
            title: 'Asansör Ata',
            subtitle: widget.customer.displayName,
          ),
          const SizedBox(height: AppSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView(
              shrinkWrap: true,
              children: [
                _ElevatorOption(
                  label: 'Bağlantıyı Kaldır',
                  subtitle: 'Müşteriyi asansörden ayır',
                  icon: Icons.link_off_rounded,
                  selected: _selectedElevatorId == null,
                  destructive: true,
                  onTap: isLoading
                      ? null
                      : () => setState(() => _selectedElevatorId = null),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final elevator in widget.elevators) ...[
                  _ElevatorOption(
                    label: elevator.buildingName,
                    subtitle: elevator.address ?? 'Adres belirtilmemiş',
                    icon: Icons.elevator_rounded,
                    selected: _selectedElevatorId == elevator.id,
                    onTap: isLoading
                        ? null
                        : () => setState(() => _selectedElevatorId = elevator.id),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: isLoading ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : Text(
                    'Kaydet',
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ElevatorOption extends StatelessWidget {
  const _ElevatorOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final accent = destructive ? colors.error : colors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.09) : colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.34) : _panelLine,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? accent : colors.outline, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.titleSmall?.copyWith(
                      color: selected ? accent : colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
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
            if (selected) Icon(Icons.check_circle_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelLine),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
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
      ],
    );
  }
}

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
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 38, color: colors.outline),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.titleSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
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
            Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
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
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
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

_RoleStyle _roleStyle(BuildContext context, UserRole role) {
  final colors = AppThemeColors.of(context);
  switch (role) {
    case UserRole.admin:
      return _RoleStyle(
        bg: colors.primary,
        fg: colors.onPrimary,
        avatarBg: colors.primary,
        avatarFg: colors.onPrimary,
        icon: Icons.admin_panel_settings_rounded,
      );
    case UserRole.customer:
      return _RoleStyle(
        bg: colors.successContainer,
        fg: colors.success,
        avatarBg: colors.success,
        avatarFg: colors.onPrimary,
        icon: Icons.apartment_rounded,
      );
    case UserRole.technician:
      return _RoleStyle(
        bg: colors.primary.withValues(alpha: 0.12),
        fg: colors.primary,
        avatarBg: colors.primary.withValues(alpha: 0.86),
        avatarFg: colors.onPrimary,
        icon: Icons.engineering_rounded,
      );
  }
}

List<ProfileModel> _filterProfiles(
  List<ProfileModel> profiles,
  String query, [
  List<ElevatorModel>? elevators,
]) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return profiles;

  return profiles.where((profile) {
    final elevator = _linkedElevator(profile, elevators);
    final haystack = [
      profile.displayName,
      profile.email ?? '',
      profile.phone ?? '',
      _roleLabel(profile.role),
      elevator?.buildingName ?? '',
      elevator?.address ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }).toList();
}

ElevatorModel? _linkedElevator(
  ProfileModel profile,
  List<ElevatorModel>? elevators,
) {
  final id = profile.elevatorId;
  if (id == null || elevators == null) return null;
  for (final elevator in elevators) {
    if (elevator.id == id) return elevator;
  }
  return null;
}

ElevatorModel? _elevatorById(List<ElevatorModel> elevators, String? id) {
  if (id == null) return null;
  for (final elevator in elevators) {
    if (elevator.id == id) return elevator;
  }
  return null;
}

String _roleLabel(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.technician:
      return 'Teknisyen';
    case UserRole.customer:
      return 'Müşteri';
  }
}

String _roleDescription(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Tüm yönetim yetkilerine sahip kullanıcı';
    case UserRole.technician:
      return 'Bakım, arıza ve saha görevlerini yönetir';
    case UserRole.customer:
      return 'Kendi asansör durumunu ve bakım geçmişini izler';
  }
}

String _shortId(String id) {
  if (id.length <= 12) return 'ID: $id';
  return 'ID: ${id.substring(0, 8)}...${id.substring(id.length - 4)}';
}

void _showSheetSnack(BuildContext context, String message, {bool isError = false}) {
  final colors = AppThemeColors.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? colors.error : colors.primary,
    ),
  );
}

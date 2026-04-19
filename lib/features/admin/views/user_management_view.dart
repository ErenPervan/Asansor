import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../elevator/models/elevator_model.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../models/profile_model.dart';
import '../providers/profile_providers.dart';

// ── Design tokens (mirrors AdminDashboard palette) ────────────────────────────

const _primary = Color(0xFFB91C1C);
const _primaryContainer = Color(0xFF991B1B);
const _error = Color(0xFFDC2626);
const _success = Color(0xFF166534);
const _successContainer = Color(0xFFDCFCE7);
const _surfaceContainerLowest = Colors.white;
const _surfaceContainer = Color(0xFFF1F5F9);
const _outlineVariant = Color(0xFFE2E8F0);
const _onSurface = Color(0xFF0F172A);
const _onSurfaceVariant = Color(0xFF475569);
const _outline = Color(0xFF94A3B8);
const _background = Color(0xFFF9FAFB);

// ── Role helpers ──────────────────────────────────────────────────────────────

_RoleStyle _roleStyle(String role) {
  switch (role) {
    case 'admin':
      return const _RoleStyle(
        bg: _primary,
        fg: Colors.white,
        avatarBg: _primaryContainer,
        avatarFg: Colors.white,
        icon: Icons.admin_panel_settings_outlined,
      );
    case 'customer':
      return const _RoleStyle(
        bg: _successContainer,
        fg: _success,
        avatarBg: Color(0xFF4CAF50),
        avatarFg: Colors.white,
        icon: Icons.person_outline,
      );
    default: // technician
      return _RoleStyle(
        bg: const Color(0xFFD6E3FF),
        fg: _primary,
        avatarBg: _primary.withValues(alpha: 0.80),
        avatarFg: Colors.white,
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
    ref.invalidate(profilesByRoleProvider('technician'));
    ref.invalidate(profilesByRoleProvider('customer'));
    ref.invalidate(profilesByRoleProvider('admin'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Kullanıcı Yönetimi',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
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
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.engineering_outlined, size: 18), text: 'Teknisyenler'),
            Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Müşteriler'),
            Tab(icon: Icon(Icons.groups_outlined, size: 18), text: 'Tüm Kullanıcılar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _UserListTab(role: 'technician'),
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
  final String? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRole = ref.watch(roleProvider);
    final profilesAsync = role == null
        ? ref.watch(allProfilesProvider)
        : ref.watch(profilesByRoleProvider(role!));

    return profilesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _primary),
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
            icon: role == 'technician'
                ? Icons.engineering_outlined
                : Icons.groups_outlined,
            message: role == 'technician'
                ? 'Henüz teknisyen kaydı yok.'
                : 'Henüz kullanıcı kaydı yok.',
          );
        }
        return RefreshIndicator(
          color: _primary,
          onRefresh: () async => role == null
              ? ref.invalidate(allProfilesProvider)
              : ref.invalidate(profilesByRoleProvider(role!)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            separatorBuilder: (context, i) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _ProfileCard(
              profile: profiles[i],
              isAdminViewer: currentRole == 'admin',
              onEditRole: () => _showEditRoleSheet(context, profiles[i]),
            ),
          ),
        );
      },
    );
  }
}

// ── Customer tab (includes elevator assignment) ───────────────────────────────

class _CustomerTab extends ConsumerWidget {
  const _CustomerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRole = ref.watch(roleProvider);
    final profilesAsync = ref.watch(profilesByRoleProvider('customer'));
    final elevatorsAsync = ref.watch(elevatorsProvider);

    return profilesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _primary),
      ),
      error: (e, _) => _ErrorPane(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(profilesByRoleProvider('customer')),
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
          color: _primary,
          onRefresh: () async {
            ref.invalidate(profilesByRoleProvider('customer'));
            ref.invalidate(elevatorsProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            separatorBuilder: (context, i) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _ProfileCard(
              profile: customers[i],
              isAdminViewer: currentRole == 'admin',
              elevators: elevators,
              onEditRole: () => _showEditRoleSheet(context, customers[i]),
              onAssignElevator: currentRole == 'admin'
                  ? () => _showAssignElevatorSheet(
                        context,
                        customers[i],
                        elevators,
                      )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isAdminViewer,
    this.elevators,
    required this.onEditRole,
    this.onAssignElevator,
  });

  final ProfileModel profile;
  final bool isAdminViewer;
  final List<ElevatorModel>? elevators;
  final VoidCallback onEditRole;
  final VoidCallback? onAssignElevator;

  @override
  Widget build(BuildContext context) {
    final style = _roleStyle(profile.role);

    ElevatorModel? linkedElevator;
    if (profile.elevatorId != null && elevators != null) {
      try {
        linkedElevator =
            elevators!.firstWhere((e) => e.id == profile.elevatorId);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  style: TextStyle(
                    color: style.avatarFg,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profile.email != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.email!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: _onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            profile.phone!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Role badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 12, color: style.fg),
                    const SizedBox(width: 4),
                    Text(
                      profile.roleTr,
                      style: TextStyle(
                        fontSize: 11,
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
            Divider(height: 1, color: _outlineVariant.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.elevator_outlined,
                  size: 14,
                  color: _onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: linkedElevator != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              linkedElevator.buildingName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (linkedElevator.address != null)
                              Text(
                                linkedElevator.address!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _outline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        )
                      : const Text(
                          'Asansör bağlı değil',
                          style: TextStyle(
                            fontSize: 12,
                            color: _outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                ),
                if (onAssignElevator != null) ...[
                  const SizedBox(width: 8),
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
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // ── Admin action row ─────────────────────────────────────────
          if (isAdminViewer) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEditRole,
                  icon: const Icon(Icons.manage_accounts_outlined, size: 14),
                  label: const Text(
                    'Rol Değiştir',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _onSurfaceVariant,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    backgroundColor: Colors.white,
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
  late String _selectedRole;

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
          content: Text(
            state.error.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _error,
        ),
      );
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.profile.displayName} artık '
            '${_roleTr(_selectedRole)} olarak güncellendi.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(profileUpdateControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                    color: _outlineVariant,
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
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.manage_accounts_outlined,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rol Değiştir',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _onSurface,
                          ),
                        ),
                        Text(
                          widget.profile.displayName,
                          style:
                              const TextStyle(fontSize: 13, color: _outline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Role options
              ...[
                ('admin', 'Admin', Icons.admin_panel_settings_outlined,
                    'Tüm yetkilere sahip yönetici'),
                ('technician', 'Teknisyen', Icons.engineering_outlined,
                    'Asansör bakım ve arıza yönetimi'),
                ('customer', 'Müşteri', Icons.person_outline,
                    'Bina sakini / asansör kullanıcısı'),
              ].map((item) {
                final (roleValue, roleLabel, roleIcon, roleSubtitle) = item;
                final style = _roleStyle(roleValue);
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
                            : _surfaceContainer,
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
                              color: isSelected ? style.bg : _outlineVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(roleIcon,
                                size: 18,
                                color: isSelected ? style.fg : Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  roleLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isSelected ? style.fg : _onSurface,
                                  ),
                                ),
                                Text(
                                  roleSubtitle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle,
                                color: style.fg, size: 20),
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
                  backgroundColor: _primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Kaydet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
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
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AssignElevatorSheet(
      customer: customer,
      elevators: elevators,
    ),
  );
}

class _AssignElevatorSheet extends ConsumerStatefulWidget {
  const _AssignElevatorSheet({
    required this.customer,
    required this.elevators,
  });
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
          content: Text(
            state.error.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _error,
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
          backgroundColor: _success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(profileUpdateControllerProvider).isLoading;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.elevator_outlined, color: _primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Asansör Ata',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _onSurface,
                          ),
                        ),
                        Text(
                          widget.customer.displayName,
                          style:
                              const TextStyle(fontSize: 13, color: _outline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: _outlineVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),

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
                          : () =>
                              setState(() => _selectedElevatorId = null),
                    ),
                    const SizedBox(height: 6),
                    ...widget.elevators.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _ElevatorOption(
                            label: e.buildingName,
                            subtitle: e.address ?? 'Adres belirtilmemiş',
                            icon: Icons.elevator_outlined,
                            isSelected: _selectedElevatorId == e.id,
                            onTap: isLoading
                                ? null
                                : () => setState(
                                    () => _selectedElevatorId = e.id),
                          ),
                        )),
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // Save button (pinned at bottom)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: FilledButton(
                    onPressed: isLoading ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Kaydet',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
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
    final accentColor = isDestructive ? _error : _primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : _surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? accentColor : _outline, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? accentColor : _onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: _outline),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: _outlineVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _outline, fontWeight: FontWeight.w500),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: _error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: FilledButton.styleFrom(backgroundColor: _primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _roleTr(String role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'customer':
      return 'Müşteri';
    default:
      return 'Teknisyen';
  }
}

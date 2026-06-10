import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/admin/views/widgets/user_management_helpers.dart';

void showEditRoleSheet(BuildContext context, ProfileModel profile) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditRoleSheet(profile: profile),
  );
}

class EditRoleSheet extends ConsumerStatefulWidget {
  const EditRoleSheet({super.key, required this.profile});

  final ProfileModel profile;

  @override
  ConsumerState<EditRoleSheet> createState() => _EditRoleSheetState();
}

class _EditRoleSheetState extends ConsumerState<EditRoleSheet> {
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
      showSheetSnack(
        context,
        state.error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
      return;
    }

    Navigator.of(context).pop();
    showSheetSnack(
      context,
      '${widget.profile.displayName} rolü ${roleLabel(_selectedRole)} olarak güncellendi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isLoading = ref.watch(profileUpdateControllerProvider).isLoading;

    return SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Rol Değiştir',
            subtitle: widget.profile.displayName,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final option in UserRole.values) ...[
            RoleOption(
              role: option,
              selected: _selectedRole == option,
              onTap: isLoading
                  ? null
                  : () => setState(() => _selectedRole = option),
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

class RoleOption extends StatelessWidget {
  const RoleOption({
    super.key,
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
    final style = roleStyle(context, role);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? style.fg.withValues(alpha: 0.10)
              : colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? style.fg.withValues(alpha: 0.38) : panelLine,
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
                    roleLabel(role),
                    style: textTheme.titleSmall?.copyWith(
                      color: selected ? style.fg : colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    roleDescription(role),
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

void showAssignElevatorSheet(
  BuildContext context,
  ProfileModel customer,
  List<ElevatorModel> elevators,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        AssignElevatorSheet(customer: customer, elevators: elevators),
  );
}

class AssignElevatorSheet extends ConsumerStatefulWidget {
  const AssignElevatorSheet({super.key, required this.customer, required this.elevators});

  final ProfileModel customer;
  final List<ElevatorModel> elevators;

  @override
  ConsumerState<AssignElevatorSheet> createState() =>
      _AssignElevatorSheetState();
}

class _AssignElevatorSheetState extends ConsumerState<AssignElevatorSheet> {
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
      showSheetSnack(
        context,
        state.error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
      return;
    }

    final elevator = elevatorById(widget.elevators, _selectedElevatorId);
    Navigator.of(context).pop();
    showSheetSnack(
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

    return SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(
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
                ElevatorOption(
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
                  ElevatorOption(
                    label: elevator.buildingName,
                    subtitle: elevator.address ?? 'Adres belirtilmemiş',
                    icon: Icons.elevator_rounded,
                    selected: _selectedElevatorId == elevator.id,
                    onTap: isLoading
                        ? null
                        : () =>
                              setState(() => _selectedElevatorId = elevator.id),
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

class ElevatorOption extends StatelessWidget {
  const ElevatorOption({
    super.key,
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
            color: selected ? accent.withValues(alpha: 0.34) : panelLine,
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

class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: panelLine),
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

class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
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

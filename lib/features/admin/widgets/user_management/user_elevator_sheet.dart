import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asansor/features/admin/widgets/user_management/user_management_shared.dart';
import 'package:asansor/features/admin/widgets/user_management/user_management_utils.dart';

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
        _AssignElevatorSheet(customer: customer, elevators: elevators),
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
      showSheetSnack(
        context,
        state.error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
      return;
    }

    final elevator = getElevatorById(widget.elevators, _selectedElevatorId);
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

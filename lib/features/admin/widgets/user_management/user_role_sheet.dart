import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asansor/features/admin/widgets/user_management/user_management_shared.dart';
import 'package:asansor/features/admin/widgets/user_management/user_management_utils.dart';

void showEditRoleSheet(BuildContext context, ProfileModel profile) {
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
      '${widget.profile.displayName} rolü ${getRoleLabel(_selectedRole)} olarak güncellendi.',
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
            _RoleOption(
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
    final style = getRoleStyle(context, role);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color:
              selected ? style.fg.withValues(alpha: 0.10) : colors.background,
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
                    getRoleLabel(role),
                    style: textTheme.titleSmall?.copyWith(
                      color: selected ? style.fg : colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    getRoleDescription(role),
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

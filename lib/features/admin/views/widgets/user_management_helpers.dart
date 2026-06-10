import 'package:flutter/material.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';

const panelLine = Color(0xFFE1E8F0);

class RoleStyle {
  const RoleStyle({
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

RoleStyle roleStyle(BuildContext context, UserRole role) {
  final colors = AppThemeColors.of(context);
  switch (role) {
    case UserRole.admin:
      return RoleStyle(
        bg: colors.primary,
        fg: colors.onPrimary,
        avatarBg: colors.primary,
        avatarFg: colors.onPrimary,
        icon: Icons.admin_panel_settings_rounded,
      );
    case UserRole.customer:
      return RoleStyle(
        bg: colors.successContainer,
        fg: colors.success,
        avatarBg: colors.success,
        avatarFg: colors.onPrimary,
        icon: Icons.apartment_rounded,
      );
    case UserRole.technician:
      return RoleStyle(
        bg: colors.primary.withValues(alpha: 0.12),
        fg: colors.primary,
        avatarBg: colors.primary.withValues(alpha: 0.86),
        avatarFg: colors.onPrimary,
        icon: Icons.engineering_rounded,
      );
  }
}

List<ProfileModel> filterProfiles(
  List<ProfileModel> profiles,
  String query, [
  List<ElevatorModel>? elevators,
]) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return profiles;

  return profiles.where((profile) {
    final elevator = linkedElevator(profile, elevators);
    final haystack = [
      profile.displayName,
      profile.email ?? '',
      profile.phone ?? '',
      roleLabel(profile.role),
      elevator?.buildingName ?? '',
      elevator?.address ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }).toList();
}

ElevatorModel? linkedElevator(
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

ElevatorModel? elevatorById(List<ElevatorModel> elevators, String? id) {
  if (id == null) return null;
  for (final elevator in elevators) {
    if (elevator.id == id) return elevator;
  }
  return null;
}

String roleLabel(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.technician:
      return 'Teknisyen';
    case UserRole.customer:
      return 'Müşteri';
  }
}

String roleDescription(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Tüm yönetim yetkilerine sahip kullanıcı';
    case UserRole.technician:
      return 'Bakım, arıza ve saha görevlerini yönetir';
    case UserRole.customer:
      return 'Kendi asansör durumunu ve bakım geçmişini izler';
  }
}

String shortId(String id) {
  if (id.length <= 12) return 'ID: $id';
  return 'ID: ${id.substring(0, 8)}...${id.substring(id.length - 4)}';
}

void showSheetSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final colors = AppThemeColors.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? colors.error : colors.primary,
    ),
  );
}

class EmptyPane extends StatelessWidget {
  const EmptyPane({super.key, required this.icon, required this.message});

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

class ErrorPane extends StatelessWidget {
  const ErrorPane({super.key, required this.message, required this.onRetry});

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

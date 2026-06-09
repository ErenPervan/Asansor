import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:flutter/material.dart';

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

RoleStyle getRoleStyle(BuildContext context, UserRole role) {
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
    final elevator = getLinkedElevator(profile, elevators);
    final haystack = [
      profile.displayName,
      profile.email ?? '',
      profile.phone ?? '',
      getRoleLabel(profile.role),
      elevator?.buildingName ?? '',
      elevator?.address ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }).toList();
}

ElevatorModel? getLinkedElevator(
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

ElevatorModel? getElevatorById(List<ElevatorModel> elevators, String? id) {
  if (id == null) return null;
  for (final elevator in elevators) {
    if (elevator.id == id) return elevator;
  }
  return null;
}

String getRoleLabel(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.technician:
      return 'Teknisyen';
    case UserRole.customer:
      return 'Müşteri';
  }
}

String getRoleDescription(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Tüm yönetim yetkilerine sahip kullanıcı';
    case UserRole.technician:
      return 'Bakım, arıza ve saha görevlerini yönetir';
    case UserRole.customer:
      return 'Kendi asansör durumunu ve bakım geçmişini izler';
  }
}

String getShortId(String id) {
  if (id.length <= 12) return 'ID: $id';
  return 'ID: ${id.substring(0, 8)}...${id.substring(id.length - 4)}';
}

void showSheetSnack(BuildContext context, String message, {bool isError = false}) {
  final colors = AppThemeColors.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? colors.error : colors.primary,
    ),
  );
}

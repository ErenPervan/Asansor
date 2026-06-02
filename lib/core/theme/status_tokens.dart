import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class StatusTokens {
  static String scheduleLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'Devam Ediyor';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal Edildi';
      default:
        return 'Bekliyor';
    }
  }

  static Color scheduleBackground(String status) {
    switch (status) {
      case 'in_progress':
        return AppColors.warningContainer;
      case 'completed':
        return AppColors.successContainer;
      case 'cancelled':
        return AppColors.errorContainer;
      default:
        return AppColors.surfaceContainer;
    }
  }

  static Color scheduleForeground(String status) {
    switch (status) {
      case 'in_progress':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.onErrorContainer;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  static Color scheduleBackgroundDynamic(BuildContext context, String status) {
    final colors = AppThemeColors.of(context);
    switch (status) {
      case 'in_progress':
        return colors.warningContainer;
      case 'completed':
        return colors.successContainer;
      case 'cancelled':
        return colors.errorContainer;
      default:
        return colors.surfaceContainer;
    }
  }

  static Color scheduleForegroundDynamic(BuildContext context, String status) {
    final colors = AppThemeColors.of(context);
    switch (status) {
      case 'in_progress':
        return colors.warning;
      case 'completed':
        return colors.success;
      case 'cancelled':
        return colors.onErrorContainer;
      default:
        return colors.onSurfaceVariant;
    }
  }

  static Color elevatorBadgeBackgroundDynamic(
    BuildContext context,
    String status,
  ) {
    final colors = AppThemeColors.of(context);
    switch (status.toLowerCase()) {
      case 'active':
        return colors.success;
      case 'faulty':
        return colors.errorContainer;
      case 'under_maintenance':
        return colors.warningContainer;
      case 'inactive':
        return colors.surfaceContainer;
      default:
        return colors.surfaceContainer;
    }
  }

  static Color elevatorBadgeForegroundDynamic(
    BuildContext context,
    String status,
  ) {
    final colors = AppThemeColors.of(context);
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.white;
      case 'faulty':
        return colors.onErrorContainer;
      case 'under_maintenance':
        return colors.warning;
      case 'inactive':
        return colors.outline;
      default:
        return colors.outline;
    }
  }
}

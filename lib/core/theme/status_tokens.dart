import 'package:flutter/material.dart';

import 'app_colors.dart';
import '../enums/app_enums.dart';

abstract final class StatusTokens {
  static String scheduleLabel(ScheduleStatus status) {
    switch (status) {
      case ScheduleStatus.inProgress:
        return 'Devam Ediyor';
      case ScheduleStatus.completed:
        return 'Tamamlandı';
      case ScheduleStatus.cancelled:
        return 'İptal Edildi';
      case ScheduleStatus.pending:
        return 'Bekliyor';
    }
  }

  static Color scheduleBackground(ScheduleStatus status) {
    switch (status) {
      case ScheduleStatus.inProgress:
        return AppColors.warningContainer;
      case ScheduleStatus.completed:
        return AppColors.successContainer;
      case ScheduleStatus.cancelled:
        return AppColors.errorContainer;
      case ScheduleStatus.pending:
        return AppColors.surfaceContainer;
    }
  }

  static Color scheduleForeground(ScheduleStatus status) {
    switch (status) {
      case ScheduleStatus.inProgress:
        return AppColors.warning;
      case ScheduleStatus.completed:
        return AppColors.success;
      case ScheduleStatus.cancelled:
        return AppColors.onErrorContainer;
      case ScheduleStatus.pending:
        return AppColors.onSurfaceVariant;
    }
  }

  static Color scheduleBackgroundDynamic(BuildContext context, ScheduleStatus status) {
    final colors = AppThemeColors.of(context);
    switch (status) {
      case ScheduleStatus.inProgress:
        return colors.warningContainer;
      case ScheduleStatus.completed:
        return colors.successContainer;
      case ScheduleStatus.cancelled:
        return colors.errorContainer;
      case ScheduleStatus.pending:
        return colors.surfaceContainer;
    }
  }

  static Color scheduleForegroundDynamic(BuildContext context, ScheduleStatus status) {
    final colors = AppThemeColors.of(context);
    switch (status) {
      case ScheduleStatus.inProgress:
        return colors.warning;
      case ScheduleStatus.completed:
        return colors.success;
      case ScheduleStatus.cancelled:
        return colors.onErrorContainer;
      case ScheduleStatus.pending:
        return colors.onSurfaceVariant;
    }
  }

  static Color elevatorBadgeBackgroundDynamic(
    BuildContext context,
    ElevatorStatus status,
  ) {
    final colors = AppThemeColors.of(context);
    switch (status) {
      case ElevatorStatus.active:
        return colors.success;
      case ElevatorStatus.faulty:
        return colors.errorContainer;
      case ElevatorStatus.underMaintenance:
        return colors.warningContainer;
      case ElevatorStatus.inactive:
        return colors.surfaceContainer;
    }
  }

  static Color elevatorBadgeForegroundDynamic(
    BuildContext context,
    ElevatorStatus status,
  ) {
    final colors = AppThemeColors.of(context);
    switch (status) {
      case ElevatorStatus.active:
        return Colors.white;
      case ElevatorStatus.faulty:
        return colors.onErrorContainer;
      case ElevatorStatus.underMaintenance:
        return colors.warning;
      case ElevatorStatus.inactive:
        return colors.outline;
    }
  }
}

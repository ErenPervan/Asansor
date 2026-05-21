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
}

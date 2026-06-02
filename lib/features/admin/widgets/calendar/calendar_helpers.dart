import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

Color getPriorityColor(String p) {
  switch (p) {
    case 'low':
      return AppColors.outline;
    case 'high':
      return AppColors.warning;
    case 'emergency':
      return AppColors.error;
    default:
      return AppColors.primary;
  }
}

String getPriorityLabel(String p) {
  switch (p) {
    case 'low':
      return 'Düşük';
    case 'high':
      return 'Yüksek';
    case 'emergency':
      return 'Acil';
    default:
      return 'Normal';
  }
}

String getStatusLabel(String s) {
  switch (s) {
    case 'in_progress':
      return 'Devam Ediyor';
    case 'completed':
      return 'Tamamlandı';
    case 'cancelled':
      return 'İptal';
    default:
      return 'Bekliyor';
  }
}

Color getStatusColor(String s) {
  switch (s) {
    case 'in_progress':
      return AppColors.primary;
    case 'completed':
      return AppColors.success;
    case 'cancelled':
      return AppColors.outline;
    default:
      return AppColors.warning;
  }
}

String formatTime(DateTime dt) {
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

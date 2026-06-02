import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/enums/app_enums.dart';

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

String getStatusLabel(ScheduleStatus s) {
  switch (s) {
    case ScheduleStatus.inProgress:
      return 'Devam Ediyor';
    case ScheduleStatus.completed:
      return 'Tamamlandı';
    case ScheduleStatus.cancelled:
      return 'İptal';
    case ScheduleStatus.pending:
      return 'Bekliyor';
  }
}

Color getStatusColor(ScheduleStatus s) {
  switch (s) {
    case ScheduleStatus.inProgress:
      return AppColors.primary;
    case ScheduleStatus.completed:
      return AppColors.success;
    case ScheduleStatus.cancelled:
      return AppColors.outline;
    case ScheduleStatus.pending:
      return AppColors.warning;
  }
}

String formatTime(DateTime dt) {
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

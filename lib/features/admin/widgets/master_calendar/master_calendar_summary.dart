import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

import 'package:asansor/features/admin/widgets/master_calendar/master_calendar_constants.dart';

class MasterCalendarSummary extends StatelessWidget {
  const MasterCalendarSummary({
    super.key,
    required this.total,
    required this.active,
    required this.urgent,
    required this.completed,
    required this.filteredTotal,
    required this.allTotal,
  });

  final int total;
  final int active;
  final int urgent;
  final int completed;
  final int filteredTotal;
  final int allTotal;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _MetricTile(
          label: 'Bu Ay',
          value: '$total',
          icon: Icons.calendar_month_rounded,
          color: AppColors.primary,
        ),
        _MetricTile(
          label: 'Aktif Görev',
          value: '$active',
          icon: Icons.pending_actions_rounded,
          color: AppColors.skyBlue,
        ),
        _MetricTile(
          label: 'Öncelikli',
          value: '$urgent',
          icon: Icons.priority_high_rounded,
          color: AppColors.error,
        ),
        _MetricTile(
          label: 'Tamamlanan',
          value: '$completed',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        ),
        _MetricTile(
          label: 'Filtre',
          value: '$filteredTotal/$allTotal',
          icon: Icons.tune_rounded,
          color: AppColors.accentGold,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 188,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MasterCalendarConstants.line),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

import 'package:asansor/features/admin/widgets/technician_management/technician_management_shared.dart';

class TechnicianMetricGrid extends StatelessWidget {
  const TechnicianMetricGrid({
    super.key,
    required this.total,
    required this.active,
    required this.free,
    required this.todayTasks,
    required this.completedToday,
  });

  final int total;
  final int active;
  final int free;
  final int todayTasks;
  final int completedToday;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _MetricCard(
          label: 'Toplam Personel',
          value: total.toString(),
          icon: Icons.groups_rounded,
          color: AppColors.primary,
        ),
        _MetricCard(
          label: 'Sahada Aktif',
          value: active.toString(),
          icon: Icons.engineering_rounded,
          color: AppColors.skyBlue,
        ),
        _MetricCard(
          label: 'Müsait',
          value: free.toString(),
          icon: Icons.check_circle_rounded,
          color: AppColors.accentGold,
        ),
        _MetricCard(
          label: 'Bugün Tamamlanan',
          value: '$completedToday/$todayTasks',
          icon: Icons.task_alt_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      width: 250,
      height: 118,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: panelLine),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

import 'package:asansor/features/admin/widgets/master_calendar/master_calendar_constants.dart';

class MasterCalendarLegend extends StatelessWidget {
  const MasterCalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MasterCalendarConstants.line),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: const [
          _LegendDot(
            color: MasterCalendarConstants.dotRed,
            label: 'Acil / yüksek öncelik',
          ),
          _LegendDot(
            color: MasterCalendarConstants.dotAmber,
            label: 'Bekliyor / devam ediyor',
          ),
          _LegendDot(
            color: MasterCalendarConstants.dotGreen,
            label: 'Tamamlandı',
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppThemeColors.of(context).onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FaultDatesGrid extends StatelessWidget {
  const FaultDatesGrid({super.key, required this.fault});

  final FaultReportModel fault;

  String _formatDate(DateTime date) {
    return DateFormat('d MMM y, HH:mm', 'tr_TR').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final reported = _DateBlock(
          label: 'Bildirim Tarihi',
          icon: Icons.calendar_today_outlined,
          value: _formatDate(fault.reportedAt),
          iconColor: colors.secondary,
        );
        final targetOrResolved = _DateBlock(
          label: fault.isResolved ? 'Onarım Tarihi' : 'Hedeflenen Onarım',
          icon: fault.isResolved
              ? Icons.check_circle_outline_rounded
              : Icons.schedule_rounded,
          value: fault.isResolved && fault.resolvedAt != null
              ? _formatDate(fault.resolvedAt!)
              : _formatDate(fault.reportedAt.add(const Duration(hours: 4))),
          iconColor: fault.isResolved ? colors.success : AppColors.accentGold,
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: reported),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: targetOrResolved),
            ],
          );
        }

        return Column(
          children: [
            reported,
            const SizedBox(height: AppSpacing.md),
            targetOrResolved,
          ],
        );
      },
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({
    required this.label,
    required this.icon,
    required this.value,
    required this.iconColor,
  });

  final String label;
  final IconData icon;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

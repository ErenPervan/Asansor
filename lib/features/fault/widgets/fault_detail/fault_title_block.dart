import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:flutter/material.dart';

class FaultTitleBlock extends StatelessWidget {
  const FaultTitleBlock({super.key, required this.fault});

  final FaultReportModel fault;

  bool _isCritical(FaultReportModel fault) {
    final priority = fault.priority?.toLowerCase();
    return priority == 'high' || priority == 'emergency';
  }

  String _shortId(String id) {
    final cleaned = id.replaceAll('-', '');
    final short = cleaned.length < 8 ? cleaned : cleaned.substring(0, 8);
    return short.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final critical = _isCritical(fault);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: fault.isResolved
                ? colors.successContainer
                : colors.errorContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: fault.isResolved
                  ? colors.success.withValues(alpha: 0.2)
                  : colors.error.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                fault.isResolved
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                size: 17,
                color: fault.isResolved ? colors.success : colors.error,
              ),
              const SizedBox(width: 7),
              Text(
                fault.isResolved
                    ? 'Çözülmüş Arıza Kaydı'
                    : critical
                        ? 'Kritik Arıza Bildirimi'
                        : 'Açık Arıza Bildirimi',
                style: textTheme.labelSmall?.copyWith(
                  color: fault.isResolved
                      ? colors.success
                      : colors.onErrorContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          fault.faultType?.isNotEmpty == true ? fault.faultType! : 'Arıza Detayı',
          style: textTheme.headlineSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(Icons.tag_rounded, size: 17, color: colors.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              'ARZ-${_shortId(fault.id)}',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

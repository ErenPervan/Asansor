import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

class MaintenancePremiumPanel extends StatelessWidget {
  const MaintenancePremiumPanel({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.warning,
    this.borderColor,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final String? warning;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? colors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (warning != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              color: colors.errorContainer,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: colors.onErrorContainer,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      warning!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.onErrorContainer,
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: colors.primaryDark, size: 21),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Text(
                          title!,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Divider(color: colors.surfaceContainer),
                  const SizedBox(height: AppSpacing.md),
                ],
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MaintenanceStatusChip extends StatelessWidget {
  const MaintenanceStatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppThemeColors.of(context).onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

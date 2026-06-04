import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.borderRadius,
    this.elevation = 0,
    this.border,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadiusGeometry? borderRadius;
  final double elevation;
  final Border? border;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final theme = Theme.of(context);

    final card = Material(
      color: color ?? colors.surfaceContainerLowest,
      elevation: elevation,
      shadowColor: colors.outline.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(AppSpacing.radiusLg),
        side: border != null
            ? BorderSide(
                color: border!.top.color,
                width: border!.top.width,
              )
            : BorderSide(
                color: colors.outlineVariant,
                width: 1,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: colors.primary.withValues(alpha: 0.05),
        highlightColor: colors.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      return Padding(
        padding: margin!,
        child: card,
      );
    }

    return card;
  }
}

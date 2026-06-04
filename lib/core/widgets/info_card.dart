import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.child,
    this.accentColor,
    this.backgroundColor,
    this.borderColor,
    this.boxShadow,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppSpacing.radiusLg,
  });

  final Widget child;
  final Color? accentColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    
    return AppCard(
      padding: padding,
      color: backgroundColor ?? colors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ??
            (accentColor != null
                ? accentColor!.withValues(alpha: 0.3)
                : colors.outlineVariant),
      ),
      child: SizedBox(
        width: double.infinity,
        child: child,
      ),
    );
  }
}

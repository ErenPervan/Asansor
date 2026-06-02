import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    this.icon,
    required this.label,
    this.color,
    this.uppercase = false,
    this.iconSize = 16,
    this.gap = 6,
    this.textStyle,
  });

  final IconData? icon;
  final String label;
  final Color? color;
  final bool uppercase;
  final double iconSize;
  final double gap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final effectiveColor =
        color ?? textStyle?.color ?? colors.onSurfaceVariant;
    final effectiveLabel = uppercase ? label.toUpperCase() : label;
    
    final baseStyle = uppercase
        ? (textTheme.labelSmall ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w700,
            color: effectiveColor,
            letterSpacing: 1.2,
          )
        : (textTheme.titleSmall ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w800,
            color: effectiveColor,
            letterSpacing: 0.1,
          );
    final resolvedStyle = textStyle == null
        ? baseStyle
        : baseStyle.merge(textStyle).copyWith(color: effectiveColor);

    if (icon == null) {
      return Text(effectiveLabel, style: resolvedStyle);
    }

    return Row(
      children: [
        Icon(icon, size: iconSize, color: effectiveColor),
        if (gap > 0) SizedBox(width: gap),
        Text(effectiveLabel, style: resolvedStyle),
      ],
    );
  }
}

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
    final effectiveColor = color ?? textStyle?.color ?? AppColors.onSurfaceVariant;
    final effectiveLabel = uppercase ? label.toUpperCase() : label;
    final baseStyle = TextStyle(
      fontSize: uppercase ? 11 : 14,
      fontWeight: uppercase ? FontWeight.w700 : FontWeight.w800,
      color: effectiveColor,
      letterSpacing: uppercase ? 1.2 : 0.1,
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

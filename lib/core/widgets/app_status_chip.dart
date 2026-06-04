import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppStatusChipSize { small, medium, large }

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.icon,
    this.size = AppStatusChipSize.medium,
  });

  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData? icon;
  final AppStatusChipSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    double verticalPadding;
    double horizontalPadding;
    TextStyle textStyle;
    double iconSize;

    switch (size) {
      case AppStatusChipSize.small:
        verticalPadding = 2;
        horizontalPadding = 6;
        textStyle = theme.textTheme.labelSmall!.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        );
        iconSize = 12;
        break;
      case AppStatusChipSize.medium:
        verticalPadding = 4;
        horizontalPadding = 8;
        textStyle = theme.textTheme.labelMedium!.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        );
        iconSize = 14;
        break;
      case AppStatusChipSize.large:
        verticalPadding = 6;
        horizontalPadding = 12;
        textStyle = theme.textTheme.labelLarge!.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        );
        iconSize = 16;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}

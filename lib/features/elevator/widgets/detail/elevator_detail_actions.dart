import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/animations/animated_press_button.dart';
import 'package:flutter/material.dart';

class ElevatorDetailActions extends StatelessWidget {
  const ElevatorDetailActions({
    super.key,
    required this.onReportFault,
    required this.onLogMaintenance,
  });

  final VoidCallback onReportFault;
  final VoidCallback onLogMaintenance;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Row(
      children: [
        Expanded(
          child: ElevatorActionCard(
            onTap: onLogMaintenance,
            backgroundColor: colors.primaryDark,
            borderColor: colors.primaryDark,
            iconContainerColor: Colors.white.withValues(alpha: 0.14),
            icon: Icons.build_circle_outlined,
            iconColor: Colors.white,
            label: 'Bakım Ekle',
            labelColor: Colors.white,
            shadowColor: colors.primary.withValues(alpha: 0.22),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ElevatorActionCard(
            onTap: onReportFault,
            backgroundColor: colors.surfaceContainerLowest,
            borderColor: colors.primary.withValues(alpha: 0.2),
            iconContainerColor: colors.errorContainer.withValues(alpha: 0.7),
            icon: Icons.warning_amber_rounded,
            iconColor: colors.error,
            label: 'Arıza Bildir',
            labelColor: colors.onSurface,
            shadowColor: colors.primary.withValues(alpha: 0.05),
          ),
        ),
      ],
    );
  }
}

class ElevatorActionCard extends StatelessWidget {
  const ElevatorActionCard({
    super.key,
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconContainerColor,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.shadowColor,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconContainerColor;
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedPressButton(
      onPressed: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconContainerColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: labelColor,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

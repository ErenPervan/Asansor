import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animations/animated_press_button.dart';


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
    return Row(
      children: [
        // "Arıza Bildir" — error-container background
        Expanded(
          child: ElevatorActionCard(
            onTap: onReportFault,
            backgroundColor: AppColors.errorContainer,
            iconContainerColor: AppColors.error.withValues(alpha: 0.12),
            icon: Icons.warning_rounded,
            iconColor: AppColors.error,
            label: 'Arıza Bildir',
            labelColor: AppColors.onErrorContainer,
          ),
        ),
        const SizedBox(width: 16),
        // "Bakım Ekle" — primary background
        Expanded(
          child: ElevatorActionCard(
            onTap: onLogMaintenance,
            backgroundColor: AppColors.primary,
            iconContainerColor: Colors.white.withValues(alpha: 0.12),
            icon: Icons.assignment_outlined,
            iconColor: Colors.white,
            label: 'Bakım Ekle',
            labelColor: Colors.white,
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
    required this.iconContainerColor,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconContainerColor;
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedPressButton(
      onPressed: onTap,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          // We set onTap to null here because AnimatedPressButton handles it
          onTap: null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconContainerColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
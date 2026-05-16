import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class InspectionBadge extends StatelessWidget {
  const InspectionBadge({super.key, required this.status, this.size = 14.0});

  final String status;
  final double size;

  Color get _badgeColor {
    switch (status.toLowerCase()) {
      case 'red':
        return Colors.redAccent.shade700;
      case 'yellow':
        return Colors.amber.shade700;
      case 'blue':
        return Colors.blue.shade700;
      case 'green':
        return Colors.green.shade700;
      default:
        return AppColors.textSecondary.withValues(alpha: 0.5);
    }
  }

  String get _badgeText {
    switch (status.toLowerCase()) {
      case 'red':
        return 'Kırmızı Etiket';
      case 'yellow':
        return 'Sarı Etiket';
      case 'blue':
        return 'Mavi Etiket';
      case 'green':
        return 'Yeşil Etiket';
      default:
        return 'Etiket Yok';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size * 0.6,
            height: size * 0.6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _badgeText,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: size,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

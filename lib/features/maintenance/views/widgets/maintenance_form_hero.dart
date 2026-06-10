import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/maintenance/views/widgets/maintenance_premium_panel.dart';

class MaintenanceFormHero extends StatelessWidget {
  const MaintenanceFormHero({super.key, required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: colors.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                elevator.address?.isNotEmpty == true
                    ? elevator.address!
                    : elevator.buildingName,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Aylık Periyodik Bakım Formu',
          style: textTheme.headlineSmall?.copyWith(
            color: colors.primaryDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MaintenanceStatusChip(
              label: 'Devam Ediyor',
              color: colors.warning,
              backgroundColor: colors.surfaceContainerHigh,
            ),
            Text(
              'Kayıt No: MNT-${DateTime.now().year}-${elevator.id.substring(0, elevator.id.length < 6 ? elevator.id.length : 6).toUpperCase()}',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

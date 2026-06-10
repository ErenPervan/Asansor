import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:flutter/material.dart';

class ElevatorDetailHeader extends StatelessWidget {
  const ElevatorDetailHeader({super.key, required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
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
          _ElevatorCover(status: elevator.status),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            elevator.buildingName,
                            style: textTheme.headlineSmall?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 17,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  elevator.address?.isNotEmpty == true
                                      ? elevator.address!
                                      : 'Adres belirtilmemiş',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: colors.outlineVariant.withValues(alpha: 0.55)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DetailMetaCell(
                        label: 'Model',
                        value: elevator.model?.isNotEmpty == true
                            ? elevator.model!
                            : 'Belirtilmedi',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DetailMetaCell(
                        label: 'Kapasite',
                        value: elevator.capacity != null
                            ? '${elevator.capacity} kg'
                            : 'Belirtilmedi',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ElevatorCover extends StatelessWidget {
  const _ElevatorCover({required this.status});

  final ElevatorStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return SizedBox(
      height: 134,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primaryDark,
                  colors.primary,
                  colors.surfaceContainerHigh,
                ],
                stops: const [0.0, 0.58, 1.0],
              ),
            ),
          ),
          Positioned(
            right: -26,
            bottom: -36,
            child: Icon(
              Icons.elevator_rounded,
              size: 152,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            left: 22,
            top: 22,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 14,
            child: DetailStatusBadge(status: status),
          ),
        ],
      ),
    );
  }
}

class DetailMetaCell extends StatelessWidget {
  const DetailMetaCell({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: textTheme.bodyLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class DetailStatusBadge extends StatelessWidget {
  const DetailStatusBadge({super.key, required this.status});

  final ElevatorStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final (label, dotColor) = switch (status) {
      ElevatorStatus.active => ('Aktif & Stabil', colors.primaryDark),
      ElevatorStatus.faulty => ('Arıza Tespit Edildi', colors.error),
      ElevatorStatus.underMaintenance => ('Bakımda', colors.warning),
      ElevatorStatus.inactive => ('Pasif', colors.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

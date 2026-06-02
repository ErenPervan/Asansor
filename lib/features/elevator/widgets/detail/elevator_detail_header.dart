import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/status_tokens.dart';
import '../../../../core/enums/app_enums.dart';
import '../../models/elevator_model.dart';
import '../../../../core/widgets/info_card.dart';

class ElevatorDetailHeader extends StatelessWidget {
  const ElevatorDetailHeader({super.key, required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return InfoCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: 16,
      backgroundColor: colors.surfaceContainerLowest,
      borderColor: Colors.transparent,
      boxShadow: [
        BoxShadow(
          color: colors.onSurface.withValues(alpha: 0.04),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge — top right (Stack equivalent)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + name/address
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Elevator icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.primaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.elevator_outlined,
                        color: colors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Material(
                            color: Colors.transparent,
                            child: Text(
                              elevator.buildingName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  elevator.address ?? 'Adres belirtilmemiş',
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: colors.onSurfaceVariant,
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
              ),
              const SizedBox(width: AppSpacing.sm),
              // Dynamic status badge
              DetailStatusBadge(status: elevator.status),
            ],
          ),

          // Divider + static metadata grid
          const SizedBox(height: 20),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 20),

          // Model + Capacity — read from DB columns added to elevators table
          Row(
            children: [
              Expanded(
                child: DetailMetaCell(
                  label: 'MODEL',
                  value: elevator.model ?? '—',
                ),
              ),
              Expanded(
                child: DetailMetaCell(
                  label: 'KAPASİTE',
                  value: elevator.capacity != null
                      ? '${elevator.capacity} Kg'
                      : '—',
                ),
              ),
            ],
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
            fontWeight: FontWeight.w700,
            color: colors.outline,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────
// Stitch: <span class="bg-emerald-600 text-white ... rounded-full">DURUM: AKTİF</span>

class DetailStatusBadge extends StatelessWidget {
  const DetailStatusBadge({super.key, required this.status});

  final ElevatorStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ElevatorStatus.active => 'DURUM: AKTİF',
      ElevatorStatus.faulty => 'DURUM: ARIZALI',
      ElevatorStatus.underMaintenance => 'DURUM: BAKIMDA',
      ElevatorStatus.inactive => 'DURUM: PASİF',
    };

    final bg = StatusTokens.elevatorBadgeBackgroundDynamic(context, status);
    final fg = StatusTokens.elevatorBadgeForegroundDynamic(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

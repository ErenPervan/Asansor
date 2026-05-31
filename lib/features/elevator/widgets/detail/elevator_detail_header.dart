import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/elevator_model.dart';
import '../../../../core/widgets/info_card.dart';

class ElevatorDetailHeader extends StatelessWidget {
  const ElevatorDetailHeader({super.key, required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      padding: const EdgeInsets.all(24),
      radius: 16,
      backgroundColor: AppColors.surfaceContainerLowest,
      borderColor: Colors.transparent,
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF191C1D).withValues(alpha: 0.04),
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
                        color: AppColors.primaryFixed, // primary-fixed: #D6E3FF
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.elevator_outlined,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Material(
                            color: Colors.transparent,
                            child: Text(
                              elevator.buildingName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  elevator.address ?? 'Adres belirtilmemiş',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.onSurfaceVariant,
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
              const SizedBox(width: 8),
              // Dynamic status badge
              DetailStatusBadge(status: elevator.status),
            ],
          ),

          // Divider + static metadata grid
          const SizedBox(height: 20),
          Divider(
            height: 1,
            color: AppColors.outlineVariant.withValues(alpha: 0.15),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.outline,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
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

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status.toLowerCase()) {
      'active' => (
        'DURUM: AKTİF',
        const Color(0xFF059669), // emerald-600
        Colors.white,
      ),
      'faulty' => (
        'DURUM: ARIZALI',
        AppColors.errorContainer,
        AppColors.onErrorContainer,
      ),
      'under_maintenance' => (
        'DURUM: BAKIMDA',
        const Color(0xFFFFF3CD),
        const Color(0xFF856404),
      ),
      'inactive' => (
        'DURUM: PASİF',
        AppColors.surfaceContainer,
        AppColors.outline,
      ),
      _ => ('DURUM: BİLİNMİYOR', AppColors.surfaceContainer, AppColors.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

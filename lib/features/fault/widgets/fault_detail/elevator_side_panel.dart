import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asansor/features/fault/widgets/fault_detail/fault_premium_panel.dart';

class ElevatorSidePanel extends StatelessWidget {
  const ElevatorSidePanel({
    super.key,
    required this.fault,
    required this.elevatorAsync,
  });

  final FaultReportModel fault;
  final AsyncValue<ElevatorModel> elevatorAsync;

  @override
  Widget build(BuildContext context) {
    return FaultPremiumPanel(
      title: 'Asansör Bilgisi',
      icon: Icons.elevator_outlined,
      child: elevatorAsync.when(
        loading: () => const LoadingState(isList: false),
        error: (_, _) => const _ElevatorErrorContent(),
        data: (elevator) => _ElevatorInfoContent(
          elevator: elevator,
          fault: fault,
        ),
      ),
    );
  }
}

class _ElevatorInfoContent extends StatelessWidget {
  const _ElevatorInfoContent({required this.elevator, required this.fault});

  final ElevatorModel elevator;
  final FaultReportModel fault;

  String _elevatorStatusLabel(ElevatorModel elevator) {
    return switch (elevator.status.name) {
      'active' => 'Aktif',
      'faulty' => 'Arızalı',
      'underMaintenance' => 'Bakımda',
      'inactive' => 'Pasif',
      _ => elevator.status.name,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLine(
          icon: Icons.location_on_outlined,
          label: 'Konum',
          value: elevator.address?.isNotEmpty == true
              ? elevator.address!
              : 'Adres belirtilmemiş',
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoLine(
          icon: Icons.precision_manufacturing_outlined,
          label: 'Model / Kapasite',
          value: [
            if (elevator.model?.isNotEmpty == true) elevator.model!,
            if (elevator.capacity != null) '${elevator.capacity} kg',
          ].isEmpty
              ? 'Belirtilmedi'
              : [
                  if (elevator.model?.isNotEmpty == true) elevator.model!,
                  if (elevator.capacity != null) '${elevator.capacity} kg',
                ].join(' / '),
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoLine(
          icon: Icons.build_circle_outlined,
          label: 'Durum',
          value: _elevatorStatusLabel(elevator),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.push('/elevator/${fault.elevatorId}'),
          icon: const Icon(Icons.info_outline_rounded),
          label: const Text('Asansör Detayına Git'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primaryDark,
            backgroundColor: colors.primaryFixed.withValues(alpha: 0.22),
            side: BorderSide(color: colors.primary.withValues(alpha: 0.16)),
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.secondary, size: 21),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ElevatorErrorContent extends StatelessWidget {
  const _ElevatorErrorContent();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: colors.outline),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Asansör bilgisi yüklenemedi',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.outline,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

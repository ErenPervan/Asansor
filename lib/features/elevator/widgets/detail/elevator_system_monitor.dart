import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';

// Pending(IoT): Re-enable daily trips mock or remove when telemetry is live
final List<String> _monthsTr = [
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
];

String _fmtDateCompact(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class SystemMonitorSection extends ConsumerWidget {
  const SystemMonitorSection({super.key, required this.elevatorId});

  final String elevatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Live data ──────────────────────────────────────────────────────────
    final latestFaultAsync = ref.watch(latestFaultDateProvider(elevatorId));
    final nextMaintenanceAsync = ref.watch(
      nextScheduledMaintenanceProvider(elevatorId),
    );

    return Column(
      children: [
        // ── "Sistem İzleme" panel ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sistem İzleme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              // Pending(IoT): Re-enable IoT connections and daily trip metrics when telemetry is live
              // Stat chips
              Row(
                children: [
                  // SON ARIZA: most recent fault_reports.reported_at for this elevator.
                  Expanded(
                    child: SystemStatChip(
                      label: 'SON ARIZA',
                      value: latestFaultAsync.when(
                        loading: () => '…',
                        error: (e, s) => '!',
                        data: (dt) => dt != null ? _fmtDateCompact(dt) : '—',
                      ),
                      valueColor: AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── "Sıradaki Bakım" panel ────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Background icon
              Positioned(
                right: -16,
                bottom: -16,
                child: Icon(
                  Icons.engineering_outlined,
                  size: 100,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              nextMaintenanceAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                error: (e, s) => const NextMaintenanceContent(
                  dayLabel: '!',
                  dateLabel: 'Yüklenemedi',
                ),
                data: (nextDate) {
                  if (nextDate == null) {
                    return const NextMaintenanceContent(
                      dayLabel: '—',
                      dateLabel: 'Planlanmadı',
                    );
                  }
                  final local = nextDate.toLocal();
                  final dayLabel = local.day.toString().padLeft(2, '0');
                  final dateLabel =
                      '${_monthsTr[local.month - 1]} ${local.year}';
                  return NextMaintenanceContent(
                    dayLabel: dayLabel,
                    dateLabel: dateLabel,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NextMaintenanceContent extends StatelessWidget {
  const NextMaintenanceContent({
    super.key,
    required this.dayLabel,
    required this.dateLabel,
  });

  final String dayLabel;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SIRADAKİ BAKIM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryFixed.withValues(alpha: 0.8),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          dayLabel,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          dateLabel,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Periyodik Genel Revizyon',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'Planlandı',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SystemStatusIndicator extends StatelessWidget {
  const SystemStatusIndicator({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class SystemStatChip extends StatelessWidget {
  const SystemStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

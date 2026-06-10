import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final local = dt.toLocal();
  return '${local.day} ${_monthsTr[local.month - 1]} ${local.year}';
}

class SystemMonitorSection extends ConsumerWidget {
  const SystemMonitorSection({super.key, required this.elevatorId});

  final String elevatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestFaultAsync = ref.watch(latestFaultDateProvider(elevatorId));
    final nextMaintenanceAsync = ref.watch(
      nextScheduledMaintenanceProvider(elevatorId),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 620;
        final gauge = _HealthScoreCard(latestFaultAsync: latestFaultAsync);
        final stats = _MonitorStatsColumn(
          latestFaultAsync: latestFaultAsync,
          nextMaintenanceAsync: nextMaintenanceAsync,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: gauge),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: stats),
            ],
          );
        }

        return Column(
          children: [
            gauge,
            const SizedBox(height: AppSpacing.md),
            stats,
          ],
        );
      },
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard({required this.latestFaultAsync});

  final AsyncValue<DateTime?> latestFaultAsync;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final score = latestFaultAsync.maybeWhen(
      data: (date) {
        if (date == null) return 96;
        final days = DateTime.now().difference(date.toLocal()).inDays;
        if (days <= 3) return 68;
        if (days <= 14) return 82;
        return 94;
      },
      orElse: () => 88,
    );
    final scoreColor = score < 75
        ? colors.error
        : score < 90
        ? colors.warning
        : colors.primaryDark;

    return _PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sistem Sağlık Puanı',
            style: textTheme.labelLarge?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: SizedBox(
              width: 136,
              height: 136,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: colors.surfaceContainerHigh,
                      color: scoreColor,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: textTheme.displaySmall?.copyWith(
                          color: scoreColor,
                          fontWeight: FontWeight.w900,
                          height: 0.92,
                        ),
                      ),
                      Text(
                        '%',
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              score < 75 ? 'Müdahale Gerekli' : 'Optimum Performans',
              style: textTheme.labelLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitorStatsColumn extends StatelessWidget {
  const _MonitorStatsColumn({
    required this.latestFaultAsync,
    required this.nextMaintenanceAsync,
  });

  final AsyncValue<DateTime?> latestFaultAsync;
  final AsyncValue<DateTime?> nextMaintenanceAsync;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Column(
      children: [
        ExpandedOrNatural(
          child: MonitorInfoTile(
            icon: Icons.event_available_rounded,
            iconBg: colors.primaryFixed.withValues(alpha: 0.72),
            iconColor: colors.primaryDark,
            label: 'Yaklaşan Periyodik Bakım',
            value: nextMaintenanceAsync.when(
              loading: () => 'Yükleniyor',
              error: (_, _) => 'Yüklenemedi',
              data: (dt) => dt == null ? 'Planlanmadı' : _fmtDateCompact(dt),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ExpandedOrNatural(
          child: MonitorInfoTile(
            icon: Icons.history_rounded,
            iconBg: colors.surfaceContainerHigh,
            iconColor: colors.onSurface,
            label: 'Son Kayıtlı Arıza',
            value: latestFaultAsync.when(
              loading: () => 'Yükleniyor',
              error: (_, _) => 'Yüklenemedi',
              data: (dt) =>
                  dt == null ? 'Arıza kaydı yok' : _fmtDateCompact(dt),
            ),
          ),
        ),
      ],
    );
  }
}

class ExpandedOrNatural extends StatelessWidget {
  const ExpandedOrNatural({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
          return SizedBox(height: constraints.maxHeight, child: child);
        }
        return child;
      },
    );
  }
}

class MonitorInfoTile extends StatelessWidget {
  const MonitorInfoTile({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return _PremiumPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
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
            ),
          ),
        ],
      ),
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
    final colors = AppThemeColors.of(context);
    return MonitorInfoTile(
      icon: Icons.event_available_rounded,
      iconBg: colors.primaryFixed,
      iconColor: colors.primaryDark,
      label: 'Sıradaki Bakım',
      value: '$dayLabel $dateLabel',
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
    final colors = AppThemeColors.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
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
    final colors = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

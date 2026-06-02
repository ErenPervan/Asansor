import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/widgets/animated_counter.dart';
import 'package:asansor/core/widgets/shimmer_card.dart';
import 'package:asansor/features/admin/repositories/admin_repository.dart';
import 'package:asansor/features/admin/widgets/dashboard/dashboard_banners.dart';

// ── Stats Grid ────────────────────────────────────────────────────────────────

class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({super.key, required this.stats});

  final AsyncValue<AdminStats> stats;

  @override
  Widget build(BuildContext context) {
    return stats.when(
      loading: () => const _StatsGridShimmer(),
      error: (e, _) =>
          ErrorBanner(message: e.toString().replaceFirst('Exception: ', '')),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Genel Bakış',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppThemeColors.of(context).onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              // Subtle "live" dot
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppThemeColors.of(context).success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Canlı',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppThemeColors.of(context).success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Top row: brand card (crimson) + fault alert ──────────────
          Row(
            children: [
              Expanded(
                child: DashboardStatCard(
                  value: s.totalElevators,
                  label: 'Toplam Asansör',
                  icon: Icons.elevator_outlined,
                  variant: StatVariant.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DashboardStatCard(
                  value: s.activeFaults,
                  label: 'Açık Arıza',
                  icon: Icons.warning_amber_rounded,
                  variant: s.activeFaults > 0
                      ? StatVariant.critical
                      : StatVariant.neutral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Bottom row: completed + pending ──────────────────────────
          Row(
            children: [
              Expanded(
                child: DashboardStatCard(
                  value: s.completedThisMonth,
                  label: 'Tamamlanan (Bu Ay)',
                  icon: Icons.check_circle_outline,
                  variant: StatVariant.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DashboardStatCard(
                  value: s.pendingThisMonth,
                  label: 'Bekleyen (Bu Ay)',
                  icon: Icons.pending_outlined,
                  variant: StatVariant.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGridShimmer extends StatelessWidget {
  const _StatsGridShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShimmerCard(width: 140, height: 24, borderRadius: 6),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: ShimmerCard(height: 140, borderRadius: 20)),
            SizedBox(width: 12),
            Expanded(child: ShimmerCard(height: 140, borderRadius: 20)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: ShimmerCard(height: 140, borderRadius: 20)),
            SizedBox(width: 12),
            Expanded(child: ShimmerCard(height: 140, borderRadius: 20)),
          ],
        ),
      ],
    );
  }
}

enum StatVariant { brand, critical, success, warning, neutral }

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.variant,
  });

  final int value;
  final String label;
  final IconData icon;
  final StatVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final (bg, iconBg, iconFg, valueFg, labelFg, gradient) = switch (variant) {
      StatVariant.brand => (
        colors.primary,
        Colors.white.withValues(alpha: 0.15),
        Colors.white,
        Colors.white,
        Colors.white70,
        LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primaryDark, colors.primary],
            )
            as Gradient?,
      ),
      StatVariant.critical => (
        colors.errorContainer,
        colors.error.withValues(alpha: 0.1),
        colors.error,
        colors.error,
        colors.error,
        null,
      ),
      StatVariant.success => (
        colors.successContainer,
        colors.success.withValues(alpha: 0.1),
        colors.success,
        colors.success,
        colors.success,
        null,
      ),
      StatVariant.warning => (
        colors.warningContainer,
        colors.warning.withValues(alpha: 0.1),
        colors.warning,
        colors.warning,
        colors.warning,
        null,
      ),
      StatVariant.neutral => (
        colors.surfaceContainerLowest,
        colors.surfaceContainer,
        colors.outline,
        colors.onSurface,
        colors.onSurfaceVariant,
        null,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: gradient == null
            ? Border.all(color: colors.outlineVariant.withValues(alpha: 0.6))
            : null,
        boxShadow: [
          BoxShadow(
            color: (gradient != null ? colors.primary : Colors.black)
                .withValues(alpha: gradient != null ? 0.18 : 0.04),
            blurRadius: gradient != null ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon in a soft pill
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconFg, size: 22),
          ),
          const SizedBox(height: 14),
          AnimatedCounter(
            value: value,
            duration: const Duration(milliseconds: 900),
            style: textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueFg,
              letterSpacing: -1.5,
              height: 1,
            ) ?? const TextStyle(),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: labelFg,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

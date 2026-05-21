import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/widgets/animated_counter.dart';
import 'package:asansor/features/admin/repositories/admin_repository.dart';
import 'package:asansor/features/admin/widgets/dashboard/dashboard_banners.dart';

// ── Stats Grid ────────────────────────────────────────────────────────────────

class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({super.key, required this.stats});

  final AsyncValue<AdminStats> stats;

  @override
  Widget build(BuildContext context) {
    return stats.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) =>
          ErrorBanner(message: e.toString().replaceFirst('Exception: ', '')),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Genel Bakış',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              // Subtle "live" dot
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Canlı',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
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
    final (bg, iconBg, iconFg, valueFg, labelFg, gradient) = switch (variant) {
      StatVariant.brand => (
        AppColors.primary,
        Colors.white.withValues(alpha: 0.15),
        Colors.white,
        Colors.white,
        Colors.white70,
        const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
            )
            as Gradient?,
      ),
      StatVariant.critical => (
        const Color(0xFFFFF1F2), // red-50
        const Color(0xFFFFE4E4),
        AppColors.error,
        AppColors.error,
        const Color(0xFF9F1239), // rose-800
        null,
      ),
      StatVariant.success => (
        const Color(0xFFF0FDF4), // green-50
        const Color(0xFFDCFCE7),
        AppColors.success,
        AppColors.success,
        const Color(0xFF14532D),
        null,
      ),
      StatVariant.warning => (
        const Color(0xFFFFFBEB), // amber-50
        const Color(0xFFFEF3C7),
        AppColors.warning,
        AppColors.warning,
        const Color(0xFF78350F),
        null,
      ),
      StatVariant.neutral => (
        AppColors.surfaceContainerLowest,
        AppColors.surfaceContainer,
        AppColors.outline,
        AppColors.onSurface,
        AppColors.onSurfaceVariant,
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
            ? Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6))
            : null,
        boxShadow: [
          BoxShadow(
            color: (gradient != null ? AppColors.primary : Colors.black)
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
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: valueFg,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
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

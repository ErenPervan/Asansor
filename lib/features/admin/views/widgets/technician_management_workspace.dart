import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/technician_stats.dart';
import 'package:asansor/features/admin/views/widgets/technician_management_metrics.dart';
import 'package:asansor/features/admin/views/widgets/technician_management_row_card.dart';
import 'package:asansor/features/admin/views/widgets/technician_management_detail_sheet.dart';
import 'package:asansor/features/admin/views/widgets/technician_management_states.dart';
import 'package:asansor/features/admin/views/widgets/user_management_helpers.dart'; // for panelLine

class TechnicianWorkspace extends StatelessWidget {
  const TechnicianWorkspace({super.key, required this.stats, required this.onRefresh});

  final List<TechnicianStats> stats;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const TechnicianManagementEmptyBody();

    final activeCount = stats.where((s) => s.hasActiveTasks).length;
    final freeCount = stats.length - activeCount;
    final todayTasks = stats.fold<int>(0, (sum, s) => sum + s.todayTotal);
    final completedToday = stats.fold<int>(
      0,
      (sum, s) => sum + s.todayCompleted,
    );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PageHeader(onRefresh: onRefresh),
                  const SizedBox(height: AppSpacing.lg),
                  TechnicianMetricGrid(
                    total: stats.length,
                    active: activeCount,
                    free: freeCount,
                    todayTasks: todayTasks,
                    completedToday: completedToday,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Column(
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        TechnicianRowCard(
                          stats: stats[i],
                          onOpenTasks: () =>
                              _showDetailSheet(context, stats[i]),
                        ),
                        if (i != stats.length - 1)
                          const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context, TechnicianStats stats) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TechnicianDetailSheet(stats: stats),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Flex(
          direction: compact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: compact
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: compact ? 0 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teknisyenler',
                    style: textTheme.headlineSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Operasyonel saha ekibi yönetimi ve anlık görev takibi.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (compact) const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              label: const Text('Yenile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                backgroundColor: colors.surface,
                side: const BorderSide(color: panelLine),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

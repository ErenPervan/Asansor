import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../elevator/providers/elevator_providers.dart';
import '../providers/admin_providers.dart';
import '../../../core/providers/connectivity_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/dashboard/dashboard_banners.dart';
import '../widgets/dashboard/dashboard_stats.dart';
import '../widgets/dashboard/dashboard_map_card.dart';
import '../widgets/dashboard/dashboard_user_cards.dart';
import '../widgets/dashboard/dashboard_calendar_cards.dart';
import '../widgets/dashboard/dashboard_schedule.dart';
import '../widgets/dashboard/dashboard_misc_cards.dart';

// ── AdminDashboardView ────────────────────────────────────────────────────────

class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final stats = ref.watch(adminStatsProvider);
    final schedules = ref.watch(allSchedulesProvider);
    final elevators = ref.watch(elevatorsProvider);
    final syncQueue = ref.watch(syncQueueServiceProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Yenile',
            onPressed: () {
              ref.invalidate(adminStatsProvider);
              ref.invalidate(allSchedulesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          ref.invalidate(allSchedulesProvider);
          ref.invalidate(elevatorsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (syncQueue.conflictCount > 0) ...[
                ConflictBanner(
                  count: syncQueue.conflictCount,
                  onTap: () => context.push('/admin/conflicts'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              DashboardStatsGrid(stats: stats),
              const SizedBox(height: AppSpacing.md),
              AddElevatorBanner(
                onTap: () => context.push('/admin/add-elevator'),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    DashboardMapCard(onTap: () => context.push('/admin/map')),
                    UserManagementCard(
                      onTap: () => context.push('/admin/users'),
                    ),
                    DashboardCalendarCard(
                      onTap: () => context.push('/admin/calendar'),
                    ),
                    MasterCalendarCard(
                      onTap: () => context.push('/admin/master-calendar'),
                    ),
                    TechnicianDirCard(
                      onTap: () => context.push('/admin/technicians'),
                    ),
                    ChecklistCard(
                      onTap: () => context.push('/admin/checklists'),
                    ),
                    StatisticsCard(
                      onTap: () => context.push('/admin/statistics'),
                    ),
                  ];

                  if (constraints.maxWidth >= 600) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: cards
                          .map(
                            (c) => SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: c,
                            ),
                          )
                          .toList(),
                    );
                  } else {
                    return Column(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          cards[i],
                          if (i < cards.length - 1) const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              DashboardScheduleList(
                schedules: schedules,
                elevators: elevators.valueOrNull,
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/assign'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.assignment_ind_outlined),
        label: Text(
          'Görev Ata',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Admin Paneli',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
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
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          ref.invalidate(allSchedulesProvider);
          ref.invalidate(elevatorsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (syncQueue.conflictCount > 0) ...[
                ConflictBanner(
                  count: syncQueue.conflictCount,
                  onTap: () => context.push('/admin/conflicts'),
                ),
                const SizedBox(height: 16),
              ],
              DashboardStatsGrid(stats: stats),
              const SizedBox(height: 16),
              AddElevatorBanner(
                onTap: () => context.push('/admin/add-elevator'),
              ),
              const SizedBox(height: 16),
              DashboardMapCard(onTap: () => context.push('/admin/map')),
              const SizedBox(height: 12),
              UserManagementCard(onTap: () => context.push('/admin/users')),
              const SizedBox(height: 12),
              DashboardCalendarCard(
                onTap: () => context.push('/admin/calendar'),
              ),
              const SizedBox(height: 12),
              MasterCalendarCard(
                onTap: () => context.push('/admin/master-calendar'),
              ),
              const SizedBox(height: 12),
              TechnicianDirCard(
                onTap: () => context.push('/admin/technicians'),
              ),
              const SizedBox(height: 12),
              ChecklistCard(onTap: () => context.push('/admin/checklists')),
              const SizedBox(height: 12),
              StatisticsCard(onTap: () => context.push('/admin/statistics')),
              const SizedBox(height: 32),
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.assignment_ind_outlined),
        label: const Text(
          'Görev Ata',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

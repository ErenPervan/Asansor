import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../admin/providers/admin_providers.dart';
import '../../admin/providers/profile_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../../fault/providers/fault_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../widgets/home/home_active_faults.dart';
import '../widgets/home/home_daily_agenda.dart';
import '../widgets/home/home_qr_fab.dart';
import '../widgets/home/home_stats_section.dart';
import '../widgets/home/home_top_app_bar.dart';

// ── HomeView ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final authState = ref.watch(authControllerProvider);
    final activeFaults = ref.watch(activeFaultsProvider);
    final mySchedules = ref.watch(technicianScheduleStreamProvider);
    final elevators = ref.watch(elevatorsProvider);
    final completedCount = ref.watch(completedTodayCountProvider);
    final adminStatsAsync = ref.watch(adminStatsProvider);

    final pendingCount = ref.watch(pendingSyncCountProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final userEmail = authState.valueOrNull?.email ?? '';
    final role = ref.watch(roleProvider) ?? 'technician';
    final isAdmin = role == 'admin';
    final screenW = MediaQuery.of(context).size.width;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            TopAppBar(
              userEmail: userEmail,
              pendingSyncCount: pendingCount,
              isOnline: isOnline,
              isAdmin: isAdmin,
              activeFaultCount: isAdmin
                  ? (adminStatsAsync.valueOrNull?.activeFaults ?? 0)
                  : (activeFaults.valueOrNull?.length ?? 0),
              onSignOut: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
            // Shown only when the device is offline; renders nothing otherwise.
            const OfflineBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: screenW > 600 ? 40 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    ActiveFaultsSection(
                      activeFaults: activeFaults,
                      elevators: elevators.valueOrNull,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    DailyAgendaSection(
                      mySchedules: mySchedules,
                      elevators: elevators.valueOrNull,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    StatsSection(
                      activeFaultCount: isAdmin
                          ? (adminStatsAsync.valueOrNull?.activeFaults ?? 0)
                          : (activeFaults.valueOrNull?.length ?? 0),
                      completedCount: isAdmin
                          ? (adminStatsAsync.valueOrNull?.completedThisMonth ??
                                0)
                          : (completedCount.valueOrNull ?? 0),
                      completedLabel: isAdmin
                          ? 'BU AY TAMAMLANAN'
                          : 'TAMAMLANAN',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatorsShortcutCard(
                      onTap: () => context.push('/elevators'),
                    ),
                    // Bottom padding so content clears the FAB + nav bar.
                    SizedBox(height: 100 + bottomInset),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: QrFab(onPressed: () => context.push('/scan')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }
}

// â”€â”€ Top App Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

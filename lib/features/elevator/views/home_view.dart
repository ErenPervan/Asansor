import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../admin/providers/admin_providers.dart';
import '../../admin/providers/profile_providers.dart';
import '../../../core/enums/app_enums.dart';
import '../../auth/providers/auth_providers.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../../fault/providers/fault_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../widgets/home/home_active_faults.dart';
import '../widgets/home/home_daily_agenda.dart';
import '../widgets/home/home_stats_section.dart';
import '../widgets/home/home_top_app_bar.dart';

// ── HomeView ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final screenW = MediaQuery.of(context).size.width;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Consumer(
              builder: (context, ref, _) {
                final authState = ref.watch(authControllerProvider);
                final pendingCount = ref.watch(pendingSyncCountProvider);
                final isOnline = ref.watch(isOnlineProvider);
                final role = ref.watch(roleProvider);
                final isAdmin = role == UserRole.admin;

                final activeFaultCount = isAdmin
                    ? (ref
                              .watch(adminStatsProvider)
                              .valueOrNull
                              ?.activeFaults ??
                          0)
                    : (ref.watch(activeFaultsProvider).valueOrNull?.length ??
                          0);

                return TopAppBar(
                  userEmail: authState.valueOrNull?.email ?? '',
                  pendingSyncCount: pendingCount,
                  isOnline: isOnline,
                  isAdmin: isAdmin,
                  activeFaultCount: activeFaultCount,
                  onSignOut: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                );
              },
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
                    Consumer(
                      builder: (context, ref, _) {
                        return ActiveFaultsSection(
                          activeFaults: ref.watch(activeFaultsProvider),
                          elevators: ref.watch(elevatorsProvider).valueOrNull,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Consumer(
                      builder: (context, ref, _) {
                        return DailyAgendaSection(
                          mySchedules: ref.watch(
                            technicianScheduleStreamProvider,
                          ),
                          elevators: ref.watch(elevatorsProvider).valueOrNull,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Consumer(
                      builder: (context, ref, _) {
                        final role = ref.watch(roleProvider);
                        final isAdmin = role == UserRole.admin;

                        final activeFaultCount = isAdmin
                            ? (ref
                                      .watch(adminStatsProvider)
                                      .valueOrNull
                                      ?.activeFaults ??
                                  0)
                            : (ref
                                      .watch(activeFaultsProvider)
                                      .valueOrNull
                                      ?.length ??
                                  0);

                        final completedCount = isAdmin
                            ? (ref
                                      .watch(adminStatsProvider)
                                      .valueOrNull
                                      ?.completedThisMonth ??
                                  0)
                            : (ref
                                      .watch(completedTodayCountProvider)
                                      .valueOrNull ??
                                  0);

                        return StatsSection(
                          activeFaultCount: activeFaultCount,
                          completedCount: completedCount,
                          completedLabel: isAdmin
                              ? 'BU AY TAMAMLANAN'
                              : 'TAMAMLANAN',
                        );
                      },
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
    );
  }
}

// ── Top App Bar ───────────────────────────────────────────────────────────────

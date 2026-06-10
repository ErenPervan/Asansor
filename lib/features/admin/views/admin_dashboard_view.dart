import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/schedule_model.dart';
import 'package:asansor/features/admin/providers/admin_providers.dart';
import 'package:asansor/features/admin/repositories/admin_repository.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.elevator_rounded, color: colors.primaryDark),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Asansor',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) {
              if (MediaQuery.sizeOf(context).width < 560) {
                return const SizedBox.shrink();
              }

              return TextButton(
                onPressed: () {},
                child: const Text('Operasyon Yönetimi'),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () {
              ref.invalidate(adminStatsProvider);
              ref.invalidate(allSchedulesProvider);
              ref.invalidate(elevatorsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: () async {
          await Future.wait([
            ref.refresh(adminStatsProvider.future),
            ref.refresh(allSchedulesProvider.future),
            ref.refresh(elevatorsProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            150 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DashboardHeader(syncConflictCount: syncQueue.conflictCount),
                  if (syncQueue.conflictCount > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ConflictStrip(
                      count: syncQueue.conflictCount,
                      onTap: () => context.push('/admin/conflicts'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _KpiSection(stats: stats),
                  const SizedBox(height: AppSpacing.lg),
                  _ActionBentoGrid(
                    conflictCount: syncQueue.conflictCount,
                    onConflict: () => context.push('/admin/conflicts'),
                    onAddElevator: () => context.push('/admin/add-elevator'),
                    onMap: () => context.push('/admin/map'),
                    onUsers: () => context.push('/admin/users'),
                    onCalendar: () => context.push('/admin/calendar'),
                    onMasterCalendar: () =>
                        context.go('/admin/master-calendar'),
                    onTechnicians: () => context.push('/admin/technicians'),
                    onChecklists: () => context.push('/admin/checklists'),
                    onStatistics: () => context.push('/admin/statistics'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SchedulesPanel(
                    schedules: schedules,
                    elevators: elevators.valueOrNull,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/assign'),
        backgroundColor: colors.primaryDark,
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.add_task_rounded),
        label: Text(
          'Görev Ata',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors.onPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.syncConflictCount});

  final int syncConflictCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panel',
                style: textTheme.displaySmall?.copyWith(
                  color: colors.primaryDark,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sistem durumu ve günlük operasyon özeti.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _LiveChip(conflictCount: syncConflictCount),
      ],
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.conflictCount});

  final int conflictCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final isWarning = conflictCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWarning ? colors.warningContainer : colors.successContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isWarning ? colors.warning : colors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            isWarning ? '$conflictCount Çakışma' : 'Canlı',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isWarning ? colors.warning : colors.success,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictStrip extends StatelessWidget {
  const _ConflictStrip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.accentGold.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.sync_problem_rounded, color: colors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '$count veri çakışması çözüm bekliyor.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: colors.warning),
          ],
        ),
      ),
    );
  }
}

class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.stats});

  final AsyncValue<AdminStats> stats;

  @override
  Widget build(BuildContext context) {
    return stats.when(
      loading: () => const _KpiLoadingGrid(),
      error: (e, _) => _ErrorPanel(message: e.toString()),
      data: (s) => LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final cards = [
            _KpiCard(
              icon: Icons.analytics_rounded,
              label: 'Aktif Asansörler',
              value: s.totalElevators,
              caption: '+4% Bu ay',
              variant: _KpiVariant.primary,
            ),
            _KpiCard(
              icon: Icons.warning_amber_rounded,
              label: 'Kritik Arızalar',
              value: s.activeFaults,
              caption: s.activeFaults > 0 ? 'Acil Müdahale' : 'Stabil',
              variant: _KpiVariant.critical,
            ),
            _KpiCard(
              icon: Icons.event_available_rounded,
              label: 'Bekleyen Bakımlar',
              value: s.pendingThisMonth,
              caption: 'Bu Ay',
              variant: _KpiVariant.neutral,
            ),
          ];

          if (isWide) {
            return Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i < cards.length - 1)
                    const SizedBox(width: AppSpacing.md),
                ],
              ],
            );
          }

          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i < cards.length - 1) const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _KpiLoadingGrid extends StatelessWidget {
  const _KpiLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final cards = List.generate(3, (_) => const _LoadingBlock(height: 148));

        if (isWide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: AppSpacing.md),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i < cards.length - 1) const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

enum _KpiVariant { primary, critical, neutral }

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.variant,
  });

  final IconData icon;
  final String label;
  final int value;
  final String caption;
  final _KpiVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isCritical = variant == _KpiVariant.critical;
    final iconBg = switch (variant) {
      _KpiVariant.primary => colors.primaryFixed.withValues(alpha: 0.5),
      _KpiVariant.critical => colors.errorContainer,
      _KpiVariant.neutral => colors.primaryFixed.withValues(alpha: 0.36),
    };
    final iconFg = switch (variant) {
      _KpiVariant.primary => colors.primaryDark,
      _KpiVariant.critical => colors.error,
      _KpiVariant.neutral => colors.secondary,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCritical
              ? colors.error.withValues(alpha: 0.22)
              : colors.outlineVariant.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (isCritical)
            Positioned(
              right: -38,
              top: -44,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: iconFg, size: 25),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isCritical
                          ? colors.errorContainer.withValues(alpha: 0.72)
                          : colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    child: Text(
                      caption,
                      style: textTheme.labelSmall?.copyWith(
                        color: isCritical
                            ? colors.error
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$value',
                style: textTheme.headlineMedium?.copyWith(
                  color: isCritical ? colors.error : colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBentoGrid extends StatelessWidget {
  const _ActionBentoGrid({
    required this.conflictCount,
    required this.onConflict,
    required this.onAddElevator,
    required this.onMap,
    required this.onUsers,
    required this.onCalendar,
    required this.onMasterCalendar,
    required this.onTechnicians,
    required this.onChecklists,
    required this.onStatistics,
  });

  final int conflictCount;
  final VoidCallback onConflict;
  final VoidCallback onAddElevator;
  final VoidCallback onMap;
  final VoidCallback onUsers;
  final VoidCallback onCalendar;
  final VoidCallback onMasterCalendar;
  final VoidCallback onTechnicians;
  final VoidCallback onChecklists;
  final VoidCallback onStatistics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _HeroActionCard(
                            title: 'Veri Çakışmaları',
                            subtitle: '$conflictCount çözülmemiş kayıt',
                            icon: Icons.sync_problem_rounded,
                            variant: _ActionVariant.warning,
                            onTap: onConflict,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _HeroActionCard(
                            title: 'Asansör Ekle',
                            subtitle: 'Yeni ünite kaydı oluştur',
                            icon: Icons.add_circle_rounded,
                            variant: _ActionVariant.primary,
                            onTap: onAddElevator,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MiniActionGrid(
                      actions: _miniActions,
                      callbacks: [
                        onUsers,
                        onCalendar,
                        onMasterCalendar,
                        onTechnicians,
                        onChecklists,
                        onStatistics,
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(width: 360, child: _MapActionCard(onTap: onMap)),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _HeroActionCard(
                    title: 'Veri Çakışmaları',
                    subtitle: '$conflictCount çözülmemiş kayıt',
                    icon: Icons.sync_problem_rounded,
                    variant: _ActionVariant.warning,
                    onTap: onConflict,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _HeroActionCard(
                    title: 'Asansör Ekle',
                    subtitle: 'Yeni ünite kaydı oluştur',
                    icon: Icons.add_circle_rounded,
                    variant: _ActionVariant.primary,
                    onTap: onAddElevator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _MapActionCard(onTap: onMap),
            const SizedBox(height: AppSpacing.md),
            _MiniActionGrid(
              actions: _miniActions,
              callbacks: [
                onUsers,
                onCalendar,
                onMasterCalendar,
                onTechnicians,
                onChecklists,
                onStatistics,
              ],
            ),
          ],
        );
      },
    );
  }
}

final _miniActions = [
  _MiniAction('Kullanıcılar', Icons.group_rounded),
  _MiniAction('Bakım Takvimi', Icons.event_note_rounded),
  _MiniAction('Ana Takvim', Icons.calendar_month_rounded),
  _MiniAction('Teknisyenler', Icons.engineering_rounded),
  _MiniAction('Kontrol Listesi', Icons.fact_check_rounded),
  _MiniAction('İstatistikler', Icons.query_stats_rounded),
];

class _MiniAction {
  const _MiniAction(this.title, this.icon);
  final String title;
  final IconData icon;
}

enum _ActionVariant { primary, warning }

class _HeroActionCard extends StatelessWidget {
  const _HeroActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.variant,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final _ActionVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final isPrimary = variant == _ActionVariant.primary;
    final bg = isPrimary ? colors.primaryDark : AppColors.accentGold;
    final fg = isPrimary ? colors.onPrimary : const Color(0xFF241A00);

    return _PressablePanel(
      onTap: onTap,
      color: bg,
      height: 156,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 34),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapActionCard extends StatelessWidget {
  const _MapActionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return _PressablePanel(
      onTap: onTap,
      height: 328,
      color: colors.primaryDark,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapPatternPainter(
                lineColor: colors.primaryFixed.withValues(alpha: 0.18),
                markerColor: AppColors.accentGold,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.primaryDark.withValues(alpha: 0.15),
                    colors.primaryDark.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Harita',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Canlı saha takibi',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.onPrimary.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.onPrimary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.map_rounded, color: colors.onPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionGrid extends StatelessWidget {
  const _MiniActionGrid({required this.actions, required this.callbacks});

  final List<_MiniAction> actions;
  final List<VoidCallback> callbacks;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        final spacing = AppSpacing.md;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < actions.length; i++)
              SizedBox(
                width: width,
                child: _MiniActionCard(action: actions[i], onTap: callbacks[i]),
              ),
          ],
        );
      },
    );
  }
}

class _MiniActionCard extends StatelessWidget {
  const _MiniActionCard({required this.action, required this.onTap});

  final _MiniAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return _PressablePanel(
      onTap: onTap,
      height: 120,
      color: colors.surfaceContainerLowest,
      borderColor: colors.outlineVariant.withValues(alpha: 0.28),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(action.icon, color: colors.secondary, size: 30),
            const Spacer(),
            Text(
              action.title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PressablePanel extends StatelessWidget {
  const _PressablePanel({
    required this.child,
    required this.onTap,
    required this.color,
    required this.height,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final double height;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor ?? Colors.transparent),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.06),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SchedulesPanel extends StatelessWidget {
  const _SchedulesPanel({required this.schedules, required this.elevators});

  final AsyncValue<List<ScheduleModel>> schedules;
  final List<ElevatorModel>? elevators;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Güncel Görevler',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.event_note_rounded, color: colors.secondary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          schedules.when(
            loading: () => const _LoadingBlock(height: 92),
            error: (e, _) => _ErrorPanel(message: e.toString()),
            data: (list) {
              final visible = list.take(5).toList();
              if (visible.isEmpty) {
                return _EmptyTasks();
              }

              return Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    _ScheduleRow(
                      schedule: visible[i],
                      elevator: _findElevator(visible[i].elevatorId, elevators),
                    ),
                    if (i < visible.length - 1)
                      Divider(
                        color: colors.outlineVariant.withValues(alpha: 0.35),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.schedule, required this.elevator});

  final ScheduleModel schedule;
  final ElevatorModel? elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final statusColor = _scheduleColor(schedule.status, colors);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  elevator?.buildingName ?? 'Asansör',
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _taskMeta(schedule, elevator),
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _scheduleLabel(schedule.status),
              style: textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Henüz atanmış görev bulunmuyor.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.replaceFirst('Exception: ', ''),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colors.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(child: CircularProgressIndicator(color: colors.primary)),
    );
  }
}

class _MapPatternPainter extends CustomPainter {
  const _MapPatternPainter({
    required this.lineColor,
    required this.markerColor,
  });

  final Color lineColor;
  final Color markerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    for (var x = -size.height; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
    }
    for (var y = 18.0; y < size.height; y += 54) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 24), line);
    }

    final markers = [
      Offset(size.width * 0.22, size.height * 0.3),
      Offset(size.width * 0.56, size.height * 0.42),
      Offset(size.width * 0.78, size.height * 0.24),
      Offset(size.width * 0.68, size.height * 0.64),
    ];
    for (final marker in markers) {
      canvas.drawCircle(
        marker,
        9,
        Paint()..color = markerColor.withValues(alpha: 0.22),
      );
      canvas.drawCircle(marker, 4.5, Paint()..color = markerColor);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPatternPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.markerColor != markerColor;
}

ElevatorModel? _findElevator(String id, List<ElevatorModel>? elevators) {
  if (elevators == null) return null;
  for (final elevator in elevators) {
    if (elevator.id == id) return elevator;
  }
  return null;
}

String _taskMeta(ScheduleModel schedule, ElevatorModel? elevator) {
  final date = schedule.scheduledDate.toLocal();
  final dateText =
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  final tech = schedule.technicianId.isEmpty
      ? 'Atanmamış'
      : '...${schedule.technicianId.substring(schedule.technicianId.length - 6)}';
  final address = elevator?.address;
  if (address != null && address.isNotEmpty) {
    return '$address · $dateText · $tech';
  }
  return '$dateText · $tech';
}

String _scheduleLabel(ScheduleStatus status) {
  return switch (status) {
    ScheduleStatus.pending => 'Bekliyor',
    ScheduleStatus.inProgress => 'Sahada',
    ScheduleStatus.completed => 'Tamamlandı',
    ScheduleStatus.cancelled => 'İptal',
  };
}

Color _scheduleColor(ScheduleStatus status, AppThemeColors colors) {
  return switch (status) {
    ScheduleStatus.pending => colors.warning,
    ScheduleStatus.inProgress => colors.primary,
    ScheduleStatus.completed => colors.success,
    ScheduleStatus.cancelled => colors.outline,
  };
}

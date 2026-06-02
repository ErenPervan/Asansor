import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_analytics_provider.dart';

import 'package:go_router/go_router.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animations/fade_in_slide.dart';

// ── Mock data ─────────────────────────────────────────────────────────────────

class _KpiData {
  const _KpiData({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bg,
    required this.trend,
    required this.trendUp,
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bg;
  final String trend;
  final bool trendUp;
}

// ── Main view ─────────────────────────────────────────────────────────────────

class AdminStatisticsDashboard extends ConsumerStatefulWidget {
  const AdminStatisticsDashboard({super.key});

  @override
  ConsumerState<AdminStatisticsDashboard> createState() =>
      _AdminStatisticsDashboardState();
}

class _AdminStatisticsDashboardState
    extends ConsumerState<AdminStatisticsDashboard> {
  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final analyticsAsync = ref.watch(adminAnalyticsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(context, colors),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: () async {
          ref.invalidate(adminAnalyticsProvider);
          await ref.read(adminAnalyticsProvider.future);
        },
        child: analyticsAsync.when(
          data: (data) => _buildContent(context, data, colors),
          loading: () =>
              Center(child: CircularProgressIndicator(color: colors.primary)),
          error: (err, stack) => _buildError(err),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AdminAnalyticsState data,
    AppThemeColors colors,
  ) {
    final kpiCards = [
      _KpiData(
        value: data.activeFaults.toString(),
        label: 'Aktif Arızalar',
        subtitle: 'Çözüm bekliyor',
        icon: Icons.warning_amber_rounded,
        color: colors.error,
        bg: colors.errorContainer,
        trend: 'Güncel',
        trendUp: false,
      ),
      _KpiData(
        value: data.completedMaintenancesThisMonth.toString(),
        label: 'Bu Ay Çözülen',
        subtitle: 'Tamamlanan görevler',
        icon: Icons.check_circle_outline_rounded,
        color: colors.success,
        bg: colors.successContainer,
        trend: 'Bu ay',
        trendUp: true,
      ),
      _KpiData(
        value: data.totalElevators.toString(),
        label: 'Toplam Asansör',
        subtitle: 'Sistemde kayıtlı',
        icon: Icons.elevator_rounded,
        color: colors.primary,
        bg: colors.primaryContainer,
        trend: 'Sistem geneli',
        trendUp: true,
      ),
      _KpiData(
        value: data.pendingMaintenances.toString(),
        label: 'Bekleyen Bakım',
        subtitle: 'Bu ay planlanmış',
        icon: Icons.pending_actions_rounded,
        color: colors.warning,
        bg: colors.warningContainer,
        trend: 'Planlanmış',
        trendUp: false,
      ),
    ];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Performans Özeti',
            subtitle: 'Anlık sistem verileri',
          ),
          const SizedBox(height: 16),
          _KpiGrid(kpiCards: kpiCards),
          const SizedBox(height: 32),
          _SectionHeader(
            title: 'Aylık Arıza Trendi',
            subtitle: 'Son 6 aylık arıza kayıtları',
            trailing: _LegendDot(color: colors.primary, label: 'Arıza'),
          ),
          const SizedBox(height: 16),
          FadeInSlide(
            index: 1,
            child: _BarChartCard(monthlyFaults: data.monthlyFaults),
          ),
          const SizedBox(height: 32),
          const _SectionHeader(
            title: 'Arıza Dağılımı',
            subtitle: 'Bileşen bazında analiz',
          ),
          const SizedBox(height: 16),
          FadeInSlide(
            index: 2,
            child: _PieChartCard(
              pieSlices: data.faultCategories,
              touchedIndex: _touchedPieIndex,
              onTouch: (i) => setState(() => _touchedPieIndex = i),
            ),
          ),
          const SizedBox(height: 32),
          const _SectionHeader(
            title: 'Hızlı Eylemler',
            subtitle: 'Sık kullanılan yönetim işlemleri',
          ),
          const SizedBox(height: 16),
          const _QuickActionsGrid(),
        ],
      ),
    );
  }

  Widget _buildError(Object err) {
    return ErrorState(
      message: 'Veriler yüklenemedi:\n$err',
      onRetry: () {
        ref.invalidate(adminAnalyticsProvider);
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppThemeColors colors,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: Container(
        decoration: BoxDecoration(color: colors.primary),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: colors.onPrimary,
                    size: 20,
                  ),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'İstatistikler & Analizler',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Yönetici Paneli',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onPrimary.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.onPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.onPrimary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colors.successLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Canlı',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

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
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── KPI Cards ─────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpiCards});
  final List<_KpiData> kpiCards;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: kpiCards.length,
      itemBuilder: (_, i) => _KpiCard(data: kpiCards[i]),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppThemeColors.of(context).outline),
        boxShadow: [
          BoxShadow(
            color: AppThemeColors.of(context).onSurface.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: data.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: data.trendUp
                      ? AppThemeColors.of(context).successContainer
                      : AppThemeColors.of(
                          context,
                        ).errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      data.trendUp
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 11,
                      color: data.trendUp
                          ? AppThemeColors.of(context).success
                          : AppThemeColors.of(context).error,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: data.color,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppThemeColors.of(context).onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            data.trend,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: data.trendUp
                  ? AppThemeColors.of(context).success
                  : AppThemeColors.of(context).outline,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Bar Chart ─────────────────────────────────────────────────────────────────

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({required this.monthlyFaults});
  final List<MonthlyFaultData> monthlyFaults;

  @override
  Widget build(BuildContext context) {
    final maxY = monthlyFaults.isEmpty
        ? 10.0
        : monthlyFaults.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color: AppThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppThemeColors.of(context).outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            maxY: maxY + 5,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppThemeColors.of(context).onSurface,
                tooltipBorderRadius: const BorderRadius.all(
                  Radius.circular(10),
                ),
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final colors = AppThemeColors.of(context);
                  final textTheme = Theme.of(context).textTheme;
                  return BarTooltipItem(
                    '${monthlyFaults[groupIndex].month}\n',
                    textTheme.labelSmall!.copyWith(
                      color: colors.surface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: '${rod.toY.toInt()} arıza',
                        style: textTheme.titleSmall?.copyWith(
                          color: colors.surface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= monthlyFaults.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        monthlyFaults[i].month,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeColors.of(context).onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 5,
                  getTitlesWidget: (value, meta) {
                    if (value % 5 != 0) return const SizedBox.shrink();
                    return Text(
                      value.toInt().toString(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppThemeColors.of(context).outline,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 5,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppThemeColors.of(context).outline,
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: monthlyFaults.asMap().entries.map((entry) {
              final i = entry.key;
              final data = entry.value;
              final isLast = i == monthlyFaults.length - 1;
              final colors = AppThemeColors.of(context);
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data.value,
                    width: 28,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: isLast
                          ? [colors.primaryDark, colors.primary]
                          : [
                              colors.primary.withValues(alpha: 0.35),
                              colors.primary.withValues(alpha: 0.65),
                            ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Pie Chart ─────────────────────────────────────────────────────────────────

class _PieChartCard extends StatelessWidget {
  const _PieChartCard({
    required this.pieSlices,
    required this.touchedIndex,
    required this.onTouch,
  });

  final List<FaultCategoryData> pieSlices;

  final int touchedIndex;
  final ValueChanged<int> onTouch;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline),
        boxShadow: [
          BoxShadow(
            color: AppThemeColors.of(context).onSurface.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Doughnut
          SizedBox(
            width: 160,
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 42,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (response != null &&
                        response.touchedSection != null &&
                        event.isInterestedForInteractions) {
                      onTouch(response.touchedSection!.touchedSectionIndex);
                    } else if (!event.isInterestedForInteractions) {
                      onTouch(-1);
                    }
                  },
                ),
                sections: pieSlices.asMap().entries.map((entry) {
                  final i = entry.key;
                  final slice = entry.value;
                  final isTouched = i == touchedIndex;
                  return PieChartSectionData(
                    value: slice.percent,
                    color: slice.color,
                    radius: isTouched ? 50 : 42,
                    showTitle: false,
                    borderSide: isTouched
                        ? BorderSide(
                            color: slice.color.withValues(alpha: 0.4),
                            width: 4,
                          )
                        : const BorderSide(color: Colors.transparent),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: pieSlices.asMap().entries.map((entry) {
                final i = entry.key;
                final slice = entry.value;
                final isTouched = i == touchedIndex;
                return Semantics(
                  button: true,
                  label: '${slice.label}, ${slice.percent.toInt()}%',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onTouch(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: isTouched
                          ? const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            )
                          : const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                      constraints: const BoxConstraints(minHeight: 48),
                      decoration: BoxDecoration(
                        color: isTouched
                            ? slice.color.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: slice.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              slice.label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: isTouched
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isTouched
                                        ? colors.onSurface
                                        : colors.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          Text(
                            '${slice.percent.toInt()}%',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isTouched
                                      ? slice.color
                                      : colors.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.route,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final String route;
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final quickActions = [
      _QuickAction(
        label: 'Rapor İndir',
        icon: Icons.download_rounded,
        color: colors.primary,
        bg: colors.primaryContainer,
        route: '',
      ),
      _QuickAction(
        label: 'Arızalar',
        icon: Icons.build_circle_outlined,
        color: colors.error,
        bg: colors.errorContainer,
        route: '/',
      ),
      _QuickAction(
        label: 'Harita',
        icon: Icons.map_outlined,
        color: colors.teal,
        bg: colors.tealContainer,
        route: '/admin/map',
      ),
      _QuickAction(
        label: 'Teknisyenler',
        icon: Icons.engineering_outlined,
        color: colors.violet,
        bg: colors.violetContainer,
        route: '/admin/technicians',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: quickActions.length,
      itemBuilder: (_, i) {
        final action = quickActions[i];
        return GestureDetector(
          onTap: () {
            if (action.route.isNotEmpty) {
              context.push(action.route);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outline),
              boxShadow: [
                BoxShadow(
                  color: colors.onSurface.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: action.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(action.icon, color: action.color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/providers/admin_analytics_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final analytics = ref.watch(adminAnalyticsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'İstatistikler',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.primaryDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(adminAnalyticsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: () async {
          ref.invalidate(adminAnalyticsProvider);
          await ref.read(adminAnalyticsProvider.future);
        },
        child: analytics.when(
          loading: () => const LoadingState(),
          error: (err, _) => ErrorState(
            message: 'Veriler yüklenemedi:\n$err',
            onRetry: () => ref.invalidate(adminAnalyticsProvider),
          ),
          data: (data) => _StatisticsContent(
            data: data,
            touchedPieIndex: _touchedPieIndex,
            onPieTouch: (index) => setState(() => _touchedPieIndex = index),
            onRefresh: () => ref.invalidate(adminAnalyticsProvider),
          ),
        ),
      ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({
    required this.data,
    required this.touchedPieIndex,
    required this.onPieTouch,
    required this.onRefresh,
  });

  final AdminAnalyticsState data;
  final int touchedPieIndex;
  final ValueChanged<int> onPieTouch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        110,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(data: data),
              const SizedBox(height: AppSpacing.lg),
              _KpiBento(data: data),
              const SizedBox(height: AppSpacing.lg),
              _InsightBento(
                data: data,
                touchedPieIndex: touchedPieIndex,
                onPieTouch: onPieTouch,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ActionStrip(onRefresh: onRefresh),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final AdminAnalyticsState data;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final totalWork =
        data.activeFaults +
        data.pendingMaintenances +
        data.completedMaintenancesThisMonth;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.16),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -46,
            child: Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 52,
            bottom: -70,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: colors.primaryFixed.withValues(alpha: 0.09),
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.query_stats_rounded,
                      color: colors.onPrimary,
                    ),
                  ),
                  const Spacer(),
                  _LiveBadge(),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Executive Dashboard',
                style: textTheme.headlineMedium?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Canlı operasyon metrikleri, bakım performansı ve arıza dağılımı.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _HeaderMetric(label: 'Toplam İş', value: '$totalWork'),
                  _HeaderMetric(
                    label: 'Asansör',
                    value: '${data.totalElevators}',
                  ),
                  _HeaderMetric(
                    label: 'Bekleyen',
                    value: '${data.pendingMaintenances}',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: colors.onPrimary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors.successLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'Canlı',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.accentGold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiBento extends StatelessWidget {
  const _KpiBento({required this.data});

  final AdminAnalyticsState data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;
        final isTablet = constraints.maxWidth >= 620;
        final cards = [
          _KpiCard(
            label: 'Aktif Arızalar',
            value: data.activeFaults.toString(),
            caption: 'Çözüm bekliyor',
            group: 'Operasyon',
            icon: Icons.warning_rounded,
            tone: _KpiTone.danger,
          ),
          _KpiCard(
            label: 'Bu Ay Çözülen',
            value: data.completedMaintenancesThisMonth.toString(),
            caption: 'Tamamlanan işler',
            group: 'Performans',
            icon: Icons.task_alt_rounded,
            tone: _KpiTone.success,
          ),
          _KpiCard(
            label: 'Bekleyen Bakım',
            value: data.pendingMaintenances.toString(),
            caption: 'Planlanmış görev',
            group: 'Planlama',
            icon: Icons.pending_actions_rounded,
            tone: _KpiTone.warning,
          ),
          _KpiCard(
            label: 'Toplam Asansör',
            value: data.totalElevators.toString(),
            caption: 'Sistemde kayıtlı',
            group: 'Sistem',
            icon: Icons.elevator_rounded,
            tone: _KpiTone.navy,
          ),
        ];

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

        if (isTablet) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: cards[3]),
                ],
              ),
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

enum _KpiTone { danger, success, warning, navy }

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.group,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final String caption;
  final String group;
  final IconData icon;
  final _KpiTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDark = tone == _KpiTone.navy;
    final accent = _accentColor(tone, colors);
    final panelColor = isDark
        ? colors.primaryDark
        : colors.surfaceContainerLowest;
    final textColor = isDark ? colors.onPrimary : colors.onSurface;
    final mutedColor = isDark
        ? colors.onPrimary.withValues(alpha: 0.7)
        : colors.onSurfaceVariant;

    return Container(
      constraints: const BoxConstraints(minHeight: 166),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? colors.primaryFixed.withValues(alpha: 0.12)
              : colors.outlineVariant.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: isDark ? 0.13 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (isDark)
            Positioned(
              right: -54,
              top: -58,
              child: Container(
                width: 134,
                height: 134,
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.12),
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.onPrimary.withValues(alpha: 0.12)
                          : accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: isDark ? colors.onPrimary : accent,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.onPrimary.withValues(alpha: 0.12)
                          : colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    child: Text(
                      group,
                      style: textTheme.labelSmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: textTheme.headlineLarge?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      caption,
                      style: textTheme.labelSmall?.copyWith(
                        color: isDark ? AppColors.accentGold : accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightBento extends StatelessWidget {
  const _InsightBento({
    required this.data,
    required this.touchedPieIndex,
    required this.onPieTouch,
  });

  final AdminAnalyticsState data;
  final int touchedPieIndex;
  final ValueChanged<int> onPieTouch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final trend = _TrendChartCard(monthlyFaults: data.monthlyFaults);
        final pie = _PieChartCard(
          pieSlices: data.faultCategories,
          touchedIndex: touchedPieIndex,
          onTouch: onPieTouch,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: trend),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: pie),
            ],
          );
        }

        return Column(
          children: [
            trend,
            const SizedBox(height: AppSpacing.md),
            pie,
          ],
        );
      },
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({required this.monthlyFaults});

  final List<MonthlyFaultData> monthlyFaults;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final maxValue = monthlyFaults.isEmpty
        ? 10.0
        : monthlyFaults.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 10.0 : maxValue + 5;

    return _PremiumPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            title: 'Aylık Arıza Trendi',
            subtitle: 'Son 6 ayın karşılaştırması',
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colors.onSurface,
                    tooltipBorderRadius: BorderRadius.circular(10),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = monthlyFaults[groupIndex];
                      return BarTooltipItem(
                        '${item.month}\n',
                        Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: colors.surface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()} arıza',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: colors.surface,
                                  fontWeight: FontWeight.w900,
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
                      reservedSize: 34,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= monthlyFaults.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            monthlyFaults[i].month,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: maxY <= 10 ? 2 : 5,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.outline,
                                fontWeight: FontWeight.w700,
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
                  horizontalInterval: maxY <= 10 ? 2 : 5,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: colors.outlineVariant.withValues(alpha: 0.42),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: monthlyFaults.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isLast = i == monthlyFaults.length - 1;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: item.value,
                        width: 30,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isLast
                              ? [colors.primaryDark, AppColors.accentGold]
                              : [
                                  colors.primary.withValues(alpha: 0.28),
                                  colors.primary.withValues(alpha: 0.72),
                                ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final selected = touchedIndex >= 0 && touchedIndex < pieSlices.length
        ? pieSlices[touchedIndex]
        : pieSlices.first;

    return _PremiumPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            title: 'Arıza Dağılımı',
            subtitle: 'Bileşen bazında analiz',
            icon: Icons.pie_chart_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: SizedBox(
              width: 190,
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 58,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (response != null &&
                              response.touchedSection != null &&
                              event.isInterestedForInteractions) {
                            onTouch(
                              response.touchedSection!.touchedSectionIndex,
                            );
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
                          radius: isTouched ? 36 : 30,
                          showTitle: false,
                          borderSide: BorderSide(
                            color: isTouched
                                ? slice.color.withValues(alpha: 0.38)
                                : Colors.transparent,
                            width: isTouched ? 4 : 0,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${selected.percent.toInt()}%',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        selected.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Column(
            children: pieSlices.asMap().entries.map((entry) {
              final i = entry.key;
              final slice = entry.value;
              final isSelected = i == touchedIndex;
              return InkWell(
                onTap: () => onTouch(i),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? slice.color.withValues(alpha: 0.09)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
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
                                color: colors.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${slice.percent.toInt()}%',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: isSelected
                                  ? slice.color
                                  : colors.onSurfaceVariant,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionStrip extends StatelessWidget {
  const _ActionStrip({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 6
            : constraints.maxWidth >= 620
            ? 3
            : 2;
        final spacing = AppSpacing.md;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final actions = [
          _ActionItem(
            label: 'Arızalar',
            icon: Icons.warning_rounded,
            onTap: () => context.push('/'),
          ),
          _ActionItem(
            label: 'Teknisyenler',
            icon: Icons.engineering_rounded,
            onTap: () => context.push('/admin/technicians'),
          ),
          _ActionItem(
            label: 'Rol Yönetimi',
            icon: Icons.manage_accounts_rounded,
            onTap: () => context.push('/admin/users'),
          ),
          _ActionItem(
            label: 'Harita',
            icon: Icons.map_rounded,
            onTap: () => context.push('/admin/map'),
          ),
          _ActionItem(
            label: 'Takvim',
            icon: Icons.calendar_month_rounded,
            onTap: () => context.push('/admin/calendar'),
          ),
          _ActionItem(
            label: 'Yenile',
            icon: Icons.refresh_rounded,
            onTap: onRefresh,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: _ActionCard(action: action),
              ),
          ],
        );
      },
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final _ActionItem action;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 96,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(action.icon, color: colors.primaryDark),
              const Spacer(),
              Text(
                action.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primaryFixed.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: colors.primaryDark),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel({required this.child, required this.padding});

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
          color: colors.outlineVariant.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

Color _accentColor(_KpiTone tone, AppThemeColors colors) {
  return switch (tone) {
    _KpiTone.danger => colors.error,
    _KpiTone.success => colors.success,
    _KpiTone.warning => colors.warning,
    _KpiTone.navy => colors.primaryDark,
  };
}

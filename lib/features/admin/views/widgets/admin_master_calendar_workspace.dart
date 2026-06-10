import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/schedule_with_details.dart';
import 'package:asansor/features/admin/views/widgets/admin_master_calendar_helpers.dart'; // for panelLine
import 'package:asansor/features/admin/views/widgets/admin_master_calendar_panel.dart';
import 'package:asansor/features/admin/views/widgets/admin_master_calendar_day_panel.dart';

class MasterCalendarWorkspace extends StatelessWidget {
  const MasterCalendarWorkspace({
    super.key,
    required this.allSchedules,
    required this.filteredSchedules,
    required this.eventMap,
    required this.dayTasks,
    required this.focusedDay,
    required this.selectedDay,
    required this.filterActive,
    required this.isGenerating,
    required this.onRefresh,
    required this.onFilter,
    required this.onAutoSchedule,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final List<ScheduleWithDetails> allSchedules;
  final List<ScheduleWithDetails> filteredSchedules;
  final Map<String, List<ScheduleWithDetails>> eventMap;
  final List<ScheduleWithDetails> dayTasks;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final bool filterActive;
  final bool isGenerating;
  final VoidCallback onRefresh;
  final VoidCallback onFilter;
  final VoidCallback onAutoSchedule;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;

  @override
  Widget build(BuildContext context) {
    final monthTasks = filteredSchedules
        .where((task) => _sameMonth(task.scheduledDate, focusedDay))
        .toList();
    final completed = monthTasks.where((task) => task.isCompleted).length;
    final active = monthTasks
        .where((task) => !task.isCompleted && !task.isCancelled)
        .length;
    final urgent = monthTasks
        .where(
          (task) =>
              (task.priority == 'emergency' || task.priority == 'high') &&
              !task.isCompleted &&
              !task.isCancelled,
        )
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 20, wide ? 24 : 16, 112),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PageHeader(
                    focusedDay: focusedDay,
                    filterActive: filterActive,
                    onRefresh: onRefresh,
                    onFilter: onFilter,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SummaryRow(
                    total: monthTasks.length,
                    active: active,
                    urgent: urgent,
                    completed: completed,
                    filteredTotal: filteredSchedules.length,
                    allTotal: allSchedules.length,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const CalendarLegend(),
                  const SizedBox(height: AppSpacing.lg),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AdminMasterCalendarPanel(
                            focusedDay: focusedDay,
                            selectedDay: selectedDay,
                            eventMap: eventMap,
                            onDaySelected: onDaySelected,
                            onPageChanged: onPageChanged,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        SizedBox(
                          width: 380,
                          child: AdminMasterCalendarDayPanel(
                            day: selectedDay,
                            tasks: dayTasks,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    AdminMasterCalendarPanel(
                      focusedDay: focusedDay,
                      selectedDay: selectedDay,
                      eventMap: eventMap,
                      onDaySelected: onDaySelected,
                      onPageChanged: onPageChanged,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AdminMasterCalendarDayPanel(day: selectedDay, tasks: dayTasks),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: isGenerating ? null : onAutoSchedule,
                      icon: isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_calendar_rounded),
                      label: Text(
                        isGenerating ? 'Oluşturuluyor' : 'Bu Ayı Planla',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.focusedDay,
    required this.filterActive,
    required this.onRefresh,
    required this.onFilter,
  });

  final DateTime focusedDay;
  final bool filterActive;
  final VoidCallback onRefresh;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final month = DateFormat('MMMM y', 'tr_TR').format(focusedDay);

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ana Takvim',
                style: textTheme.displaySmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$month operasyon planı, öncelikler ve teknisyen dağılımı',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarButton(
              icon: Icons.refresh_rounded,
              label: 'Yenile',
              onPressed: onRefresh,
            ),
            const SizedBox(width: AppSpacing.sm),
            _ToolbarButton(
              icon: Icons.filter_list_rounded,
              label: 'Filtrele',
              active: filterActive,
              onPressed: onFilter,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.total,
    required this.active,
    required this.urgent,
    required this.completed,
    required this.filteredTotal,
    required this.allTotal,
  });

  final int total;
  final int active;
  final int urgent;
  final int completed;
  final int filteredTotal;
  final int allTotal;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _MetricTile(
          label: 'Bu Ay',
          value: '$total',
          icon: Icons.calendar_month_rounded,
          color: AppColors.primary,
        ),
        _MetricTile(
          label: 'Aktif Görev',
          value: '$active',
          icon: Icons.pending_actions_rounded,
          color: AppColors.skyBlue,
        ),
        _MetricTile(
          label: 'Öncelikli',
          value: '$urgent',
          icon: Icons.priority_high_rounded,
          color: AppColors.error,
        ),
        _MetricTile(
          label: 'Tamamlanan',
          value: '$completed',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        ),
        _MetricTile(
          label: 'Filtre',
          value: '$filteredTotal/$allTotal',
          icon: Icons.tune_rounded,
          color: AppColors.accentGold,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 188,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: panelLine),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 19),
          if (active)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.accentGold,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        backgroundColor: colors.surface,
        side: const BorderSide(color: panelLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

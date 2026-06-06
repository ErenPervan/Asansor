import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/app_section_header.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/models/schedule_with_details.dart';
import 'package:asansor/features/admin/providers/admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

const _dotRed = AppColors.error;
const _dotGreen = AppColors.successLight;
const _dotAmber = AppColors.warningLight;
const _line = Color(0xFFE1E8F0);

class AdminMasterCalendarView extends ConsumerStatefulWidget {
  const AdminMasterCalendarView({super.key});

  @override
  ConsumerState<AdminMasterCalendarView> createState() =>
      _AdminMasterCalendarViewState();
}

class _AdminMasterCalendarViewState
    extends ConsumerState<AdminMasterCalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final allAsync = ref.watch(allSchedulesWithDetailsProvider);
    final filter = ref.watch(masterCalendarFilterProvider);
    final autoScheduleState = ref.watch(autoScheduleControllerProvider);
    final isGenerating = autoScheduleState.isLoading;

    ref.listen(autoScheduleControllerProvider, (prev, next) {
      next.whenOrNull(
        data: (result) {
          if (result == null) return;
          final msg = result.inserted > 0
              ? '${result.inserted} adet asansörün bakımı takvime eklendi.'
              : 'Bu ay için tüm periyodik bakımlar zaten mevcut.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
              backgroundColor: result.inserted > 0
                  ? AppColors.success
                  : AppColors.onSurfaceVariant,
              duration: const Duration(seconds: 4),
            ),
          );
        },
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: colors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.domain_rounded,
                color: colors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'ElevateOps Pro',
              style: textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isGenerating
            ? null
            : () => _confirmAutoSchedule(context, _focusedDay),
        icon: isGenerating
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onPrimary,
                ),
              )
            : const Icon(Icons.edit_calendar_rounded),
        label: Text(isGenerating ? 'Oluşturuluyor' : 'Bu Ayı Planla'),
        backgroundColor: isGenerating ? colors.outline : colors.primary,
      ),
      body: allAsync.when(
        loading: () => const LoadingState(),
        error: (e, st) => _ErrorView(
          error: e,
          onRetry: () => ref.invalidate(allSchedulesWithDetailsProvider),
        ),
        data: (all) {
          final filtered = _applyFilter(all, filter);
          final eventMap = _buildEventMap(filtered);
          final dayTasks = List<ScheduleWithDetails>.from(
            eventMap[_dayKey(_selectedDay)] ?? [],
          )..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

          return _MasterCalendarWorkspace(
            allSchedules: all,
            filteredSchedules: filtered,
            eventMap: eventMap,
            dayTasks: dayTasks,
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            filterActive: filter.isActive,
            isGenerating: isGenerating,
            onRefresh: () => ref.invalidate(allSchedulesWithDetailsProvider),
            onFilter: () => _showFilterSheet(context, all),
            onAutoSchedule: () => _confirmAutoSchedule(context, _focusedDay),
            onDaySelected: (sel, foc) => setState(() {
              _selectedDay = sel;
              _focusedDay = foc;
            }),
            onPageChanged: (foc) => setState(() => _focusedDay = foc),
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context, List<ScheduleWithDetails> all) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(allSchedules: all),
    );
  }

  Future<void> _confirmAutoSchedule(
    BuildContext context,
    DateTime month,
  ) async {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final monthLabel = DateFormat('MMMM y', 'tr_TR').format(month);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.edit_calendar_rounded,
                color: colors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Otomatik Planlama',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '$monthLabel ayı için eksik olan tüm periyodik bakımlar otomatik '
          'oluşturulacak.\n\nOnaylıyor musunuz?',
          style: textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: colors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'İptal',
              style: textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              minimumSize: const Size(96, 40),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(autoScheduleControllerProvider.notifier).generate(month);
    }
  }

  static List<ScheduleWithDetails> _applyFilter(
    List<ScheduleWithDetails> all,
    MasterCalendarFilter filter,
  ) {
    var result = all;
    if (filter.technicianId != null) {
      result = result
          .where((s) => s.technicianId == filter.technicianId)
          .toList();
    }
    if (filter.status != null) {
      result = result.where((s) => s.status.dbValue == filter.status).toList();
    }
    return result;
  }

  static Map<String, List<ScheduleWithDetails>> _buildEventMap(
    List<ScheduleWithDetails> schedules,
  ) {
    final map = <String, List<ScheduleWithDetails>>{};
    for (final schedule in schedules) {
      final key = _dayKey(schedule.scheduledDate.toLocal());
      map.putIfAbsent(key, () => []).add(schedule);
    }
    return map;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _MasterCalendarWorkspace extends StatelessWidget {
  const _MasterCalendarWorkspace({
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
          padding: EdgeInsets.fromLTRB(
            wide ? 24 : 16,
            20,
            wide ? 24 : 16,
            112,
          ),
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
                          child: _CalendarPanel(
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
                          child: _SelectedDayPanel(
                            day: selectedDay,
                            tasks: dayTasks,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _CalendarPanel(
                      focusedDay: focusedDay,
                      selectedDay: selectedDay,
                      eventMap: eventMap,
                      onDaySelected: onDaySelected,
                      onPageChanged: onPageChanged,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SelectedDayPanel(day: selectedDay, tasks: dayTasks),
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
        border: Border.all(color: _line),
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
        side: const BorderSide(color: _line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.focusedDay,
    required this.selectedDay,
    required this.eventMap,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final Map<String, List<ScheduleWithDetails>> eventMap;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowHeight = constraints.maxWidth >= 720 ? 84.0 : 56.0;

          return TableCalendar<ScheduleWithDetails>(
            locale: 'tr_TR',
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: focusedDay,
            rowHeight: rowHeight,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Ay'},
            selectedDayPredicate: (d) => isSameDay(selectedDay, d),
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
            eventLoader: (day) => eventMap[_dayKey(day)] ?? [],
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleTextFormatter: (date, locale) =>
                  DateFormat('MMMM y', locale).format(date),
              titleTextStyle: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ) ??
                  const TextStyle(),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: colors.primary,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: colors.primary,
              ),
              headerPadding: const EdgeInsets.only(bottom: 12),
            ),
            daysOfWeekHeight: 38,
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onSurfaceVariant,
                  ) ??
                  const TextStyle(),
              weekendStyle: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.outline,
                  ) ??
                  const TextStyle(),
            ),
            calendarStyle: CalendarStyle(
              cellMargin: const EdgeInsets.all(3),
              outsideDaysVisible: false,
              defaultDecoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(8),
              ),
              weekendDecoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(8),
              ),
              selectedDecoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                border: Border.all(color: colors.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.accentGold, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              selectedTextStyle: textTheme.bodyMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ) ??
                  const TextStyle(),
              todayTextStyle: textTheme.bodyMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w900,
                  ) ??
                  const TextStyle(),
              defaultTextStyle: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ) ??
                  const TextStyle(),
              weekendTextStyle: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ) ??
                  const TextStyle(),
              markerDecoration: const BoxDecoration(shape: BoxShape.circle),
              markersMaxCount: 3,
            ),
            calendarBuilders: CalendarBuilders<ScheduleWithDetails>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                return Positioned(
                  bottom: rowHeight >= 70 ? 10 : 5,
                  child: _MarkerDots(events: events.take(3).toList()),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _MarkerDots extends StatelessWidget {
  const _MarkerDots({required this.events});

  final List<ScheduleWithDetails> events;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final event in events) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _markerColor(event),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
        ],
      ],
    );
  }

  static Color _markerColor(ScheduleWithDetails task) {
    if ((task.priority == 'emergency' || task.priority == 'high') &&
        !task.isCompleted &&
        !task.isCancelled) {
      return _dotRed;
    }
    if (task.isCompleted) return _dotGreen;
    return _dotAmber;
  }
}

class _SelectedDayPanel extends StatelessWidget {
  const _SelectedDayPanel({required this.day, required this.tasks});

  final DateTime day;
  final List<ScheduleWithDetails> tasks;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final title = DateFormat('d MMMM Görevleri', 'tr_TR').format(day);
    final fullDate = DateFormat('EEEE, d MMMM y', 'tr_TR').format(day);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fullDate,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _CountBadge(count: tasks.length),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: colors.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          if (tasks.isEmpty)
            _EmptyDayPlaceholder(day: day)
          else
            Column(
              children: [
                for (var i = 0; i < tasks.length; i++) ...[
                  _MasterTaskCard(task: tasks[i]),
                  if (i != tasks.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: count > 0
            ? colors.primary.withValues(alpha: 0.1)
            : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count görev',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: count > 0 ? colors.primary : colors.onSurfaceVariant,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MasterTaskCard extends StatelessWidget {
  const _MasterTaskCard({required this.task});

  final ScheduleWithDetails task;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final time = DateFormat(
      'HH:mm',
      'tr_TR',
    ).format(task.scheduledDate.toLocal());

    return Material(
      color: colors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/elevator/${task.elevatorId}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _priorityColor(context, task.priority),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _taskIconColor(context, task).$1,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _taskIcon(task),
                              color: _taskIconColor(context, task).$2,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.buildingName,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colors.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (task.address != null &&
                                    task.address!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    task.address!,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.outline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          _MiniInfo(
                            icon: Icons.person_rounded,
                            label: task.technicianName.isEmpty
                                ? 'Atanmamış'
                                : task.technicianName,
                          ),
                          _MiniInfo(icon: Icons.schedule_rounded, label: time),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _PriorityBadge(priority: task.priority),
                          _TaskStatusBadge(status: task.status),
                          if (task.isPeriodicMaintenance)
                            _Badge(
                              label: 'PERİYODİK',
                              bg: colors.primaryContainer,
                              fg: colors.primary,
                            ),
                        ],
                      ),
                      if (task.notes != null && task.notes!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          task.notes!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _priorityColor(BuildContext context, String priority) {
    final colors = AppThemeColors.of(context);
    switch (priority) {
      case 'emergency':
        return colors.error;
      case 'high':
        return colors.warning;
      case 'low':
        return colors.outline;
      default:
        return colors.primary;
    }
  }

  static IconData _taskIcon(ScheduleWithDetails task) {
    if (task.priority == 'emergency' || task.priority == 'high') {
      return Icons.warning_rounded;
    }
    if (task.isCompleted) return Icons.check_rounded;
    return Icons.build_rounded;
  }

  static (Color, Color) _taskIconColor(
    BuildContext context,
    ScheduleWithDetails task,
  ) {
    final colors = AppThemeColors.of(context);
    if (task.priority == 'emergency' || task.priority == 'high') {
      return (colors.errorContainer, colors.error);
    }
    if (task.isCompleted) {
      return (colors.successContainer, colors.success);
    }
    return (colors.primaryContainer, colors.primary);
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.outline),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _styles(context, priority);
    return _Badge(label: label, bg: bg, fg: fg);
  }

  static (String, Color, Color) _styles(BuildContext context, String p) {
    final colors = AppThemeColors.of(context);
    switch (p) {
      case 'emergency':
        return ('ACİL', colors.errorContainer, colors.error);
      case 'high':
        return ('YÜKSEK', colors.warningContainer, colors.warning);
      case 'low':
        return ('DÜŞÜK', colors.surfaceContainerHigh, colors.onSurfaceVariant);
      default:
        return ('NORMAL', colors.surfaceContainer, colors.onSurface);
    }
  }
}

class _TaskStatusBadge extends StatelessWidget {
  const _TaskStatusBadge({required this.status});

  final ScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _styles(context, status);
    return _Badge(label: label, bg: bg, fg: fg);
  }

  static (String, Color, Color) _styles(
    BuildContext context,
    ScheduleStatus status,
  ) {
    final colors = AppThemeColors.of(context);
    switch (status) {
      case ScheduleStatus.completed:
        return ('TAMAMLANDI', colors.successContainer, colors.success);
      case ScheduleStatus.inProgress:
        return ('DEVAM', colors.warningContainer, colors.warning);
      case ScheduleStatus.cancelled:
        return ('İPTAL', colors.surfaceContainerHigh, colors.onSurfaceVariant);
      case ScheduleStatus.pending:
        return ('BEKLİYOR', colors.surfaceContainer, colors.onSurface);
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: fg,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EmptyDayPlaceholder extends StatelessWidget {
  const _EmptyDayPlaceholder({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final label = DateFormat('d MMMM', 'tr_TR').format(day);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.event_available_outlined,
                size: 34,
                color: colors.outline,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '$label için planlanmış görev yok',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: colors.outline),
            const SizedBox(height: 12),
            Text(
              'Veriler yüklenemedi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.allSchedules});

  final List<ScheduleWithDetails> allSchedules;

  static const _statusOptions = [
    ('', 'Tümü'),
    ('pending', 'Bekliyor'),
    ('in_progress', 'Devam Ediyor'),
    ('completed', 'Tamamlandı'),
    ('cancelled', 'İptal Edildi'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(masterCalendarFilterProvider);
    final notifier = ref.read(masterCalendarFilterProvider.notifier);

    final seen = <String>{};
    final technicians = <MapEntry<String, String>>[];
    for (final schedule in allSchedules) {
      if (schedule.technicianId.isNotEmpty &&
          seen.add(schedule.technicianId)) {
        technicians.add(
          MapEntry(schedule.technicianId, schedule.technicianName),
        );
      }
    }
    technicians.sort((a, b) => a.value.compareTo(b.value));

    final colors = AppThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    'Filtrele',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (filter.isActive)
                    TextButton(
                      onPressed: notifier.clear,
                      child: Text(
                        'Temizle',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.outline),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (technicians.isNotEmpty) ...[
                const AppSectionHeader(title: 'TEKNİSYEN'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChipItem(
                      label: 'Tümü',
                      selected: filter.technicianId == null,
                      onSelected: () => notifier.setTechnician(null),
                    ),
                    for (final technician in technicians)
                      _FilterChipItem(
                        label: technician.value,
                        selected: filter.technicianId == technician.key,
                        onSelected: () => notifier.setTechnician(
                          filter.technicianId == technician.key
                              ? null
                              : technician.key,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: colors.outlineVariant, height: 1),
                const SizedBox(height: AppSpacing.md),
              ],
              const AppSectionHeader(title: 'DURUM'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in _statusOptions)
                    _FilterChipItem(
                      label: label,
                      selected: (filter.status ?? '') == value,
                      onSelected: () =>
                          notifier.setStatus(value.isEmpty ? null : value),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return FilterChip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: colors.primary.withValues(alpha: 0.1),
      checkmarkColor: colors.primary,
      side: BorderSide(
        color: selected
            ? colors.primary.withValues(alpha: 0.4)
            : colors.outlineVariant,
      ),
      backgroundColor: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: const [
          _LegendDot(color: _dotRed, label: 'Acil / yüksek öncelik'),
          _LegendDot(color: _dotAmber, label: 'Bekliyor / devam ediyor'),
          _LegendDot(color: _dotGreen, label: 'Tamamlandı'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppThemeColors.of(context).onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

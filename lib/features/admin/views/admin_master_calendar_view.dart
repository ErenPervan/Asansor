import 'package:asansor/core/widgets/loading_state.dart';
import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import 'package:table_calendar/table_calendar.dart';

import '../models/schedule_with_details.dart';

import '../providers/admin_providers.dart';
import '../../../core/enums/app_enums.dart';

import '../../../core/theme/app_colors.dart';

// Dot colours for calendar markers.
const _dotRed = AppColors.error;
const _dotGreen = AppColors.successLight;
const _dotAmber = AppColors.warningLight;

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

    // Listen for auto-schedule results to show the result Snackbar.
    ref.listen(autoScheduleControllerProvider, (prev, next) {
      next.whenOrNull(
        data: (result) {
          if (result == null) return;
          final msg = result.inserted > 0
              ? '${result.inserted} adet asansÃ¶rÃ¼n bakÄ±mÄ± takvime eklendi! âœ…'
              : 'Bu ay iÃ§in tÃ¼m periyodik bakÄ±mlar zaten mevcut.';
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

    final autoScheduleState = ref.watch(autoScheduleControllerProvider);
    final isGenerating = autoScheduleState.isLoading;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Ana Takvim',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(allSchedulesWithDetailsProvider),
          ),
          // Filter with active indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.filter_list_rounded),
                  if (filter.isActive)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Filtrele',
              onPressed: allAsync.hasValue
                  ? () => _showFilterSheet(context, allAsync.value!)
                  : null,
            ),
          ),
        ],
      ),
      // â”€â”€ FAB: "Bu AyÄ± Planla" â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
            : const Icon(Icons.auto_fix_high_rounded),
        label: Text(
          isGenerating ? 'OluÅŸturuluyorâ€¦' : 'Bu AyÄ± Planla',
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
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

          return Column(
            children: [
              // â”€â”€ Calendar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _CalendarSection(
                focusedDay: _focusedDay,
                selectedDay: _selectedDay,
                eventMap: eventMap,
                onDaySelected: (sel, foc) => setState(() {
                  _selectedDay = sel;
                  _focusedDay = foc;
                }),
                onPageChanged: (foc) => setState(() => _focusedDay = foc),
              ),

              Divider(height: 1, color: colors.outlineVariant),

              // â”€â”€ Day header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _DayHeader(day: _selectedDay, taskCount: dayTasks.length),

              // â”€â”€ Task list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Expanded(
                child: dayTasks.isEmpty
                    ? _EmptyDayPlaceholder(day: _selectedDay)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: dayTasks.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _MasterTaskCard(task: dayTasks[i]),
                      ),
              ),
            ],
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

  /// Shows a confirmation dialog then triggers auto-scheduling for [month].
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_fix_high_rounded,
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
          '$monthLabel ayÄ± iÃ§in eksik olan tÃ¼m periyodik bakÄ±mlar '
          'otomatik oluÅŸturulacak.\n\n'
          'OnaylÄ±yor musunuz?',
          style: textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: colors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Ä°ptal',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              minimumSize: const Size(90, 40),
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

  // â”€â”€ Pure helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
      result = result.where((s) => s.status.name == filter.status).toList();
    }
    return result;
  }

  static Map<String, List<ScheduleWithDetails>> _buildEventMap(
    List<ScheduleWithDetails> schedules,
  ) {
    final map = <String, List<ScheduleWithDetails>>{};
    for (final s in schedules) {
      final key = _dayKey(s.scheduledDate.toLocal());
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// â”€â”€ Calendar section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({
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
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TableCalendar<ScheduleWithDetails>(
        locale: 'tr_TR',
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: focusedDay,
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Ay'},
        selectedDayPredicate: (d) => isSameDay(selectedDay, d),
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        eventLoader: (day) {
          final key =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-'
              '${day.day.toString().padLeft(2, '0')}';
          return eventMap[key] ?? [];
        },
        // â”€â”€ Style â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        calendarStyle: CalendarStyle(
          // Selected day: solid crimson circle with white text.
          selectedDecoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle:
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ) ??
              const TextStyle(),
          // Today: crimson border, no fill.
          todayDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.primary, width: 1.5),
          ),
          todayTextStyle:
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ) ??
              const TextStyle(),
          defaultDecoration: const BoxDecoration(shape: BoxShape.circle),
          weekendDecoration: const BoxDecoration(shape: BoxShape.circle),
          weekendTextStyle:
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ) ??
              const TextStyle(),
          outsideDaysVisible: false,
          cellMargin: const EdgeInsets.all(5),
          // Marker decoration is overridden by calendarBuilders below.
          markerDecoration: const BoxDecoration(shape: BoxShape.circle),
          markersMaxCount: 1,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle:
              textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
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
          headerPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle:
              textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ) ??
              const TextStyle(),
          weekendStyle:
              textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.outline,
              ) ??
              const TextStyle(),
        ),
        // â”€â”€ Marker builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        calendarBuilders: CalendarBuilders<ScheduleWithDetails>(
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return null;
            final color = _markerColor(events);
            if (color == null) return null;
            return Positioned(
              bottom: 5,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Determines the priority colour for the dot shown under a calendar day.
  ///
  /// RED  â†’ â‰¥1 emergency/high non-completed task.
  /// GREEN â†’ all active tasks are completed.
  /// AMBER â†’ â‰¥1 pending/in-progress task.
  static Color? _markerColor(List<ScheduleWithDetails> events) {
    final active = events.where((e) => e.status != ScheduleStatus.cancelled).toList();
    if (active.isEmpty) return null;

    if (active.any(
      (e) =>
          (e.priority == 'emergency' || e.priority == 'high') && !e.isCompleted,
    )) {
      return _dotRed;
    }
    if (active.every((e) => e.isCompleted)) return _dotGreen;
    return _dotAmber;
  }
}

// â”€â”€ Day header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.taskCount});

  final DateTime day;
  final int taskCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final label = DateFormat('d MMMM y, EEEE', 'tr_TR').format(day);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: colors.surfaceContainer,
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 15, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: taskCount > 0
                  ? colors.primary.withValues(alpha: 0.1)
                  : colors.outlineVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$taskCount gÃ¶rev',
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: taskCount > 0 ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Task card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/elevator/${task.elevatorId}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colors.onSurface.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Priority colour
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: _priorityStripeColor(context, task.priority),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Building name + status icon
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                task.buildingName,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _StatusIcon(status: task.status),
                          ],
                        ),

                        // Address
                        if (task.address != null &&
                            task.address!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: colors.outline,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  task.address!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: AppSpacing.sm),

                        // Technician row
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: colors.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                task.technicianName.isNotEmpty
                                    ? task.technicianName[0].toUpperCase()
                                    : '?',
                                style: textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                task.technicianName,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Time + badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: colors.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  time,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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

                        // Notes
                        if (task.notes != null && task.notes!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              task.notes!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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
      ),
    );
  }

  static Color _priorityStripeColor(BuildContext context, String priority) {
    final colors = AppThemeColors.of(context);
    switch (priority) {
      case 'emergency':
        return colors.error;
      case 'high':
        return colors.warning;
      case 'normal':
        return colors.primary;
      default: // low
        return colors.outline;
    }
  }
}

// â”€â”€ Status icon â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final ScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _data(context, status);
    return Icon(icon, size: 18, color: color);
  }

  static (IconData, Color) _data(BuildContext context, ScheduleStatus s) {
    final colors = AppThemeColors.of(context);
    switch (s) {
      case ScheduleStatus.completed:
        return (Icons.check_circle_rounded, colors.success);
      case ScheduleStatus.inProgress:
        return (Icons.autorenew_rounded, colors.warning);
      case ScheduleStatus.cancelled:
        return (Icons.cancel_rounded, colors.onSurfaceVariant);
      default: // pending
        return (Icons.schedule_rounded, colors.outline);
    }
  }
}

// â”€â”€ Priority badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
        return ('ACÄ°L', colors.errorContainer, colors.error);
      case 'high':
        return ('YÃœKSEK', colors.warningContainer, colors.warning);
      case 'low':
        return (
          'DÃœÅÃœK',
          colors.surfaceContainerHigh,
          colors.onSurfaceVariant,
        );
      default: // normal
        return ('NORMAL', colors.surfaceContainer, colors.onSurface);
    }
  }
}

// â”€â”€ Status badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TaskStatusBadge extends StatelessWidget {
  const _TaskStatusBadge({required this.status});
  final ScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _styles(context, status);
    return _Badge(label: label, bg: bg, fg: fg);
  }

  static (String, Color, Color) _styles(BuildContext context, ScheduleStatus s) {
    final colors = AppThemeColors.of(context);
    switch (s) {
      case ScheduleStatus.completed:
        return ('TAMAMLANDI', colors.successContainer, colors.success);
      case ScheduleStatus.inProgress:
        return ('DEVAM', colors.warningContainer, colors.warning);
      case ScheduleStatus.cancelled:
        return ('İPTAL', colors.surfaceContainerHigh, colors.onSurfaceVariant);
      default: // pending
        return ('BEKLİYOR', colors.surfaceContainer, colors.onSurface);
    }
  }
}

// â”€â”€ Shared badge widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// â”€â”€ Empty placeholder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyDayPlaceholder extends StatelessWidget {
  const _EmptyDayPlaceholder({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('d MMMM', 'tr_TR').format(day);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppThemeColors.of(context).surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_outlined,
                size: 36,
                color: AppThemeColors.of(context).outline,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '$label iÃ§in\nplanlanmÄ±ÅŸ gÃ¶rev yok',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppThemeColors.of(context).onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Error view â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppThemeColors.of(context).outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Veriler yÃ¼klenemedi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppThemeColors.of(context).onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppThemeColors.of(context).onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Filter sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.allSchedules});

  final List<ScheduleWithDetails> allSchedules;

  static const _statusOptions = [
    ('', 'TÃ¼mÃ¼'),
    ('pending', 'Bekliyor'),
    ('in_progress', 'Devam Ediyor'),
    ('completed', 'TamamlandÄ±'),
    ('cancelled', 'Ä°ptal Edildi'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(masterCalendarFilterProvider);
    final notifier = ref.read(masterCalendarFilterProvider.notifier);

    // Build unique, alphabetically sorted technician list.
    // Skip unassigned tasks (empty technicianId) â€” they would otherwise show
    // up as an "AtanmamÄ±ÅŸ" entry which doesn't make sense as a filter chip.
    final seen = <String>{};
    final technicians = <MapEntry<String, String>>[];
    for (final s in allSchedules) {
      if (s.technicianId.isNotEmpty && seen.add(s.technicianId)) {
        technicians.add(MapEntry(s.technicianId, s.technicianName));
      }
    }
    technicians.sort((a, b) => a.value.compareTo(b.value));

    final colors = AppThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
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

              // Header row
              Row(
                children: [
                  Text(
                    'Filtrele',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (filter.isActive)
                    TextButton(
                      onPressed: notifier.clear,
                      child: Text(
                        'Temizle',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: colors.primary),
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.outline),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // â”€â”€ Technician section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (technicians.isNotEmpty) ...[
                const _SheetSectionLabel('TEKNÄ°SYEN'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // "TÃ¼mÃ¼" chip
                    _FilterChipItem(
                      label: 'TÃ¼mÃ¼',
                      selected: filter.technicianId == null,
                      onSelected: () => notifier.setTechnician(null),
                    ),
                    for (final tech in technicians)
                      _FilterChipItem(
                        label: tech.value,
                        selected: filter.technicianId == tech.key,
                        onSelected: () => notifier.setTechnician(
                          filter.technicianId == tech.key ? null : tech.key,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: colors.outlineVariant, height: 1),
                const SizedBox(height: AppSpacing.md),
              ],

              // â”€â”€ Status section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              const _SheetSectionLabel('DURUM'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (val, lbl) in _statusOptions)
                    _FilterChipItem(
                      label: lbl,
                      selected: (filter.status ?? '') == val,
                      onSelected: () =>
                          notifier.setStatus(val.isEmpty ? null : val),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppThemeColors.of(context).onSurfaceVariant,
        letterSpacing: 1.2,
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
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

// â”€â”€ Legend row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Shown at the bottom of the calendar legend (optional, not used in main UI
/// but exported so the admin can read what each dot colour means at a glance).
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: _dotRed, label: 'Acil/YÃ¼ksek'),
        const SizedBox(width: AppSpacing.md),
        _LegendDot(color: _dotAmber, label: 'Bekliyor'),
        const SizedBox(width: AppSpacing.md),
        _LegendDot(color: _dotGreen, label: 'TamamlandÄ±'),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppThemeColors.of(context).onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/schedule_with_details.dart';
import 'package:asansor/features/admin/views/widgets/admin_master_calendar_helpers.dart';

class AdminMasterCalendarPanel extends StatelessWidget {
  const AdminMasterCalendarPanel({
    super.key,
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
        border: Border.all(color: panelLine),
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
              titleTextStyle:
                  textTheme.titleMedium?.copyWith(
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
              weekdayStyle:
                  textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onSurfaceVariant,
                  ) ??
                  const TextStyle(),
              weekendStyle:
                  textTheme.labelMedium?.copyWith(
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
                border: Border.all(color: panelLine),
                borderRadius: BorderRadius.circular(8),
              ),
              weekendDecoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: panelLine),
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
              selectedTextStyle:
                  textTheme.bodyMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ) ??
                  const TextStyle(),
              todayTextStyle:
                  textTheme.bodyMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w900,
                  ) ??
                  const TextStyle(),
              defaultTextStyle:
                  textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ) ??
                  const TextStyle(),
              weekendTextStyle:
                  textTheme.bodyMedium?.copyWith(
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
      return dotRed;
    }
    if (task.isCompleted) return dotGreen;
    return dotAmber;
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
        border: Border.all(color: panelLine),
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
          _LegendDot(color: dotRed, label: 'Acil / yüksek öncelik'),
          _LegendDot(color: dotAmber, label: 'Bekliyor / devam ediyor'),
          _LegendDot(color: dotGreen, label: 'Tamamlandı'),
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

import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/schedule_with_details.dart';
import 'package:flutter/material.dart';

import 'package:asansor/features/admin/widgets/master_calendar/master_calendar_header.dart';
import 'package:asansor/features/admin/widgets/master_calendar/master_calendar_legend.dart';
import 'package:asansor/features/admin/widgets/master_calendar/master_calendar_panel.dart';
import 'package:asansor/features/admin/widgets/master_calendar/master_calendar_selected_day.dart';
import 'package:asansor/features/admin/widgets/master_calendar/master_calendar_summary.dart';

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
                  MasterCalendarHeader(
                    focusedDay: focusedDay,
                    filterActive: filterActive,
                    onRefresh: onRefresh,
                    onFilter: onFilter,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  MasterCalendarSummary(
                    total: monthTasks.length,
                    active: active,
                    urgent: urgent,
                    completed: completed,
                    filteredTotal: filteredSchedules.length,
                    allTotal: allSchedules.length,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const MasterCalendarLegend(),
                  const SizedBox(height: AppSpacing.lg),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: MasterCalendarPanel(
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
                          child: MasterCalendarSelectedDayPanel(
                            day: selectedDay,
                            tasks: dayTasks,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    MasterCalendarPanel(
                      focusedDay: focusedDay,
                      selectedDay: selectedDay,
                      eventMap: eventMap,
                      onDaySelected: onDaySelected,
                      onPageChanged: onPageChanged,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    MasterCalendarSelectedDayPanel(
                      day: selectedDay,
                      tasks: dayTasks,
                    ),
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

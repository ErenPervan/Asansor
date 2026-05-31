import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:table_calendar/table_calendar.dart';

import '../../elevator/models/elevator_model.dart';

import '../../elevator/providers/elevator_providers.dart';

import '../models/profile_model.dart';

import '../models/schedule_model.dart';

import '../providers/admin_providers.dart';

import '../providers/profile_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/calendar/calendar_task_card.dart';
import '../widgets/calendar/calendar_assign_sheet.dart';

ElevatorModel? _findElevator(String id, List<ElevatorModel>? list) {
  if (list == null) return null;
  try {
    return list.firstWhere((e) => e.id == id);
  } catch (_) {
    return null;
  }
}

ProfileModel? _findProfile(String id, List<ProfileModel>? list) {
  if (list == null) return null;
  try {
    return list.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
}

bool _isSameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

// ── AdminCalendarView ─────────────────────────────────────────────────────────

class AdminCalendarView extends ConsumerStatefulWidget {
  const AdminCalendarView({super.key});

  @override
  ConsumerState<AdminCalendarView> createState() => _AdminCalendarViewState();
}

class _AdminCalendarViewState extends ConsumerState<AdminCalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<ScheduleModel> _eventsForDay(DateTime day, List<ScheduleModel> all) {
    return all.where((s) => _isSameLocalDay(s.scheduledDate, day)).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }

  void _onDaySelected(DateTime selected, DateTime focused) {
    if (!isSameDay(_selectedDay, selected)) {
      setState(() {
        _selectedDay = selected;
        _focusedDay = focused;
      });
    }
  }

  void _openAssignSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignTaskSheet(preselectedDate: _selectedDay),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(allSchedulesProvider);
    final elevatorsAsync = ref.watch(elevatorsProvider);
    final techsAsync = ref.watch(profilesByRoleProvider('technician'));

    final allSchedules = schedulesAsync.valueOrNull ?? [];
    final elevators = elevatorsAsync.valueOrNull;
    final techs = techsAsync.valueOrNull;

    final selectedEvents = _eventsForDay(_selectedDay, allSchedules);

    // Refresh calendar markers when a new task is assigned.
    ref.listen(scheduleControllerProvider, (_, next) {
      if (!next.isLoading && !next.hasError && next.value != null) {
        ref.invalidate(allSchedulesProvider);
      }
    });

    return Scaffold(
      backgroundColor: AppThemeColors.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Bakım Takvimi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (schedulesAsync.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          IconButton(
            onPressed: () => ref.invalidate(allSchedulesProvider),
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Calendar ─────────────────────────────────────────────────────
          Container(
            color: AppColors.surfaceContainerLowest,
            child: TableCalendar<ScheduleModel>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              onPageChanged: (focused) => _focusedDay = focused,
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Ay'},
              eventLoader: (day) => _eventsForDay(day, allSchedules),
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                markersMaxCount: 4,
                markerDecoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
                markerSize: 5,
              ),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: AppColors.primary,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.outline,
                ),
                weekendStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.outlineVariant),

          // ── Selected day header ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Text(
                  '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selectedEvents.isEmpty
                        ? AppColors.surfaceContainer
                        : AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${selectedEvents.length} Görev',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selectedEvents.isEmpty
                          ? AppColors.outline
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Task list ─────────────────────────────────────────────────────
          Expanded(
            child: selectedEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available_outlined,
                          size: 48,
                          color: AppColors.outline.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Bu gün için görev yok.',
                          style: TextStyle(
                            color: AppColors.outline,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Yeni görev atamak için + butonuna bas.',
                          style: TextStyle(
                            color: AppColors.outline.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: selectedEvents.length,
                    itemBuilder: (context, i) => CalendarTaskCard(
                      schedule: selectedEvents[i],
                      elevator: _findElevator(
                        selectedEvents[i].elevatorId,
                        elevators,
                      ),
                      technician: _findProfile(
                        selectedEvents[i].technicianId,
                        techs,
                      ),
                      onCancel:
                          selectedEvents[i].status == 'pending' ||
                              selectedEvents[i].status == 'in_progress'
                          ? () => _confirmCancel(context, selectedEvents[i].id)
                          : null,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAssignSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Görev Ata',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, String taskId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görevi İptal Et'),
        content: const Text('Bu görevi iptal etmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(scheduleControllerProvider.notifier)
                  .updateStatus(taskId: taskId, status: 'cancelled');
            },
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
  }
}

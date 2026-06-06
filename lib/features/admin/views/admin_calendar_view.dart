import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/admin/models/schedule_model.dart';
import 'package:asansor/features/admin/providers/admin_providers.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:asansor/features/admin/widgets/calendar/calendar_assign_sheet.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

ElevatorModel? _findElevator(String id, List<ElevatorModel>? list) {
  if (list == null) return null;
  for (final elevator in list) {
    if (elevator.id == id) return elevator;
  }
  return null;
}

ProfileModel? _findProfile(String id, List<ProfileModel>? list) {
  if (list == null) return null;
  for (final profile in list) {
    if (profile.id == id) return profile;
  }
  return null;
}

bool _isSameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

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
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });
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
    final colors = AppThemeColors.of(context);
    final schedulesAsync = ref.watch(allSchedulesProvider);
    final elevatorsAsync = ref.watch(elevatorsProvider);
    final techsAsync = ref.watch(profilesByRoleProvider(UserRole.technician));

    final allSchedules = schedulesAsync.valueOrNull ?? [];
    final elevators = elevatorsAsync.valueOrNull;
    final techs = techsAsync.valueOrNull;
    final selectedEvents = _eventsForDay(_selectedDay, allSchedules);

    ref.listen(scheduleControllerProvider, (_, next) {
      if (!next.isLoading && !next.hasError && next.value != null) {
        ref.invalidate(allSchedulesProvider);
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurfaceVariant),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.elevator_rounded, color: colors.primaryDark),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Asansor',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        actions: [
          if (schedulesAsync.isLoading)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              ),
            ),
          IconButton(
            onPressed: () => ref.invalidate(allSchedulesProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: () async {
          ref.invalidate(allSchedulesProvider);
          ref.invalidate(elevatorsProvider);
          ref.invalidate(profilesByRoleProvider(UserRole.technician));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            112,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CalendarPanel(
                    focusedDay: _focusedDay,
                    selectedDay: _selectedDay,
                    allSchedules: allSchedules,
                    eventsForDay: _eventsForDay,
                    onDaySelected: _onDaySelected,
                    onPageChanged: (focused) =>
                        setState(() => _focusedDay = focused),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SelectedDayHeader(
                    selectedDay: _selectedDay,
                    count: selectedEvents.length,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (selectedEvents.isEmpty)
                    _EmptyDayCard(onAssign: _openAssignSheet)
                  else
                    Column(
                      children: [
                        for (var i = 0; i < selectedEvents.length; i++) ...[
                          _TaskCard(
                            schedule: selectedEvents[i],
                            elevator: _findElevator(
                              selectedEvents[i].elevatorId,
                              elevators,
                            ),
                            technician: _findProfile(
                              selectedEvents[i].technicianId,
                              techs,
                            ),
                            onCancel: selectedEvents[i].status ==
                                        ScheduleStatus.pending ||
                                    selectedEvents[i].status ==
                                        ScheduleStatus.inProgress
                                ? () => _confirmCancel(
                                      context,
                                      selectedEvents[i].id,
                                    )
                                : null,
                          ),
                          if (i < selectedEvents.length - 1)
                            const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAssignSheet,
        backgroundColor: colors.primaryDark,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }

  void _confirmCancel(BuildContext context, String taskId) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = AppThemeColors.of(ctx);
        return AlertDialog(
          title: const Text('Görevi İptal Et'),
          content: const Text(
            'Bu görevi iptal etmek istediğinize emin misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: colors.error),
              onPressed: () {
                Navigator.pop(ctx);
                ref
                    .read(scheduleControllerProvider.notifier)
                    .updateStatus(
                      taskId: taskId,
                      status: ScheduleStatus.cancelled,
                    );
              },
              child: const Text('İptal Et'),
            ),
          ],
        );
      },
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.focusedDay,
    required this.selectedDay,
    required this.allSchedules,
    required this.eventsForDay,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<ScheduleModel> allSchedules;
  final List<ScheduleModel> Function(DateTime, List<ScheduleModel>) eventsForDay;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TableCalendar<ScheduleModel>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Ay'},
        eventLoader: (day) => eventsForDay(day, allSchedules),
        startingDayOfWeek: StartingDayOfWeek.monday,
        rowHeight: 46,
        daysOfWeekHeight: 28,
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: colors.onSurfaceVariant,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: colors.onSurfaceVariant,
          ),
          titleTextFormatter: (date, locale) => _monthTitle(date),
          titleTextStyle: textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ) ??
              const TextStyle(),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ) ??
              const TextStyle(),
          weekendStyle: textTheme.labelSmall?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w800,
              ) ??
              const TextStyle(),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          outsideTextStyle: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.32),
              ) ??
              const TextStyle(),
          weekendTextStyle: textTheme.bodyMedium?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w600,
              ) ??
              const TextStyle(),
          defaultTextStyle: textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ) ??
              const TextStyle(),
          todayDecoration: BoxDecoration(
            color: colors.primaryFixed.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          todayTextStyle: textTheme.bodyMedium?.copyWith(
                color: colors.primaryDark,
                fontWeight: FontWeight.w900,
              ) ??
              const TextStyle(),
          selectedDecoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          selectedTextStyle: textTheme.bodyMedium?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.w900,
              ) ??
              const TextStyle(),
          markersMaxCount: 3,
          markerSize: 0,
        ),
        calendarBuilders: CalendarBuilders<ScheduleModel>(
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return null;
            final visible = events.take(3).toList();
            final selected = isSameDay(selectedDay, day);
            return Positioned(
              bottom: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final event in visible)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.onPrimary
                            : _statusColor(event.status, colors),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SelectedDayHeader extends StatelessWidget {
  const _SelectedDayHeader({required this.selectedDay, required this.count});

  final DateTime selectedDay;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selectedDayTitle(selectedDay),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              '$count Görev',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.schedule,
    required this.elevator,
    required this.technician,
    required this.onCancel,
  });

  final ScheduleModel schedule;
  final ElevatorModel? elevator;
  final ProfileModel? technician;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final completed = schedule.status == ScheduleStatus.completed;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.32)),
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
          if (schedule.status == ScheduleStatus.inProgress)
            Positioned(
              left: -AppSpacing.lg,
              top: -AppSpacing.lg,
              bottom: -AppSpacing.lg,
              child: Container(width: 4, color: AppColors.accentGold),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: completed
                          ? colors.surfaceContainer
                          : colors.primaryFixed.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _buildingIcon(schedule),
                      color: completed ? colors.onSurfaceVariant : colors.primary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          elevator?.buildingName ?? 'Asansör',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: completed
                                    ? colors.onSurfaceVariant
                                    : colors.onSurface,
                                fontWeight: FontWeight.w900,
                                decoration:
                                    completed ? TextDecoration.lineThrough : null,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.engineering_rounded,
                              size: 15,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Teknisyen: ${_technicianName(schedule, technician)}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _StatusBadge(status: schedule.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(color: colors.outlineVariant.withValues(alpha: 0.32)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, color: colors.secondary, size: 19),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _timeRange(schedule.scheduledDate),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: completed
                                ? colors.onSurfaceVariant
                                : colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (onCancel != null)
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 17),
                      label: const Text('İptal'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    )
                  else if (!completed)
                    TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.more_vert_rounded, size: 17),
                      label: const Text('Detay'),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final color = _statusColor(status, colors);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == ScheduleStatus.completed) ...[
            Icon(Icons.check_circle_rounded, color: color, size: 15),
            const SizedBox(width: 5),
          ],
          Text(
            _statusLabel(status),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({required this.onAssign});

  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.32)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 46,
            color: colors.outlineVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Bu gün için görev yok.',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Yeni görev atamak için + butonunu kullanın.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onAssign,
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Görev Ata'),
          ),
        ],
      ),
    );
  }
}

String _monthTitle(DateTime date) {
  return '${_months[date.month - 1]} ${date.year}';
}

String _selectedDayTitle(DateTime date) {
  return '${date.day} ${_months[date.month - 1]}, ${_weekdays[date.weekday - 1]}';
}

String _timeRange(DateTime date) {
  final local = date.toLocal();
  final end = local.add(const Duration(hours: 1, minutes: 30));
  return '${_hhmm(local)} - ${_hhmm(end)}';
}

String _hhmm(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _technicianName(ScheduleModel schedule, ProfileModel? technician) {
  if (technician != null) return technician.displayName;
  if (schedule.technicianId.isEmpty) return 'Atanmamış';
  return schedule.technicianId.length > 8
      ? '...${schedule.technicianId.substring(schedule.technicianId.length - 8)}'
      : schedule.technicianId;
}

IconData _buildingIcon(ScheduleModel schedule) {
  return schedule.isPeriodicMaintenance
      ? Icons.domain_rounded
      : Icons.business_rounded;
}

String _statusLabel(ScheduleStatus status) {
  return switch (status) {
    ScheduleStatus.pending => 'Bekliyor',
    ScheduleStatus.inProgress => 'Devam Ediyor',
    ScheduleStatus.completed => 'Tamamlandı',
    ScheduleStatus.cancelled => 'İptal',
  };
}

Color _statusColor(ScheduleStatus status, AppThemeColors colors) {
  return switch (status) {
    ScheduleStatus.pending => colors.onSurfaceVariant,
    ScheduleStatus.inProgress => AppColors.accentGold,
    ScheduleStatus.completed => colors.primary,
    ScheduleStatus.cancelled => colors.error,
  };
}

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const _weekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

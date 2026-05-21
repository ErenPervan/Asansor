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
import '../../../core/widgets/section_label.dart';
// ── Priority helpers ──────────────────────────────────────────────────────────

Color _priorityColor(String p) {
  switch (p) {
    case 'low':
      return const Color(0xFF78909C);
    case 'high':
      return AppColors.warning;
    case 'emergency':
      return AppColors.error;
    default:
      return AppColors.primary;
  }
}

String _priorityLabel(String p) {
  switch (p) {
    case 'low':
      return 'Düşük';
    case 'high':
      return 'Yüksek';
    case 'emergency':
      return 'Acil';
    default:
      return 'Normal';
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'in_progress':
      return 'Devam Ediyor';
    case 'completed':
      return 'Tamamlandı';
    case 'cancelled':
      return 'İptal';
    default:
      return 'Bekliyor';
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'in_progress':
      return AppColors.primary;
    case 'completed':
      return const Color(0xFF2E7D32);
    case 'cancelled':
      return AppColors.outline;
    default:
      return AppColors.warning;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtTime(DateTime dt) {
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

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

  List<ScheduleModel> _eventsForDay(
    DateTime day,
    List<ScheduleModel> all,
  ) {
    return all
        .where((s) => _isSameLocalDay(s.scheduledDate, day))
        .toList()
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
      builder: (_) => _AssignTaskSheet(preselectedDate: _selectedDay),
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
      backgroundColor: AppColors.background,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      color: selectedEvents.isEmpty ? AppColors.outline : Colors.white,
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
                          style: TextStyle(color: AppColors.outline, fontSize: 14),
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
                    itemBuilder: (context, i) => _CalendarTaskCard(
                      schedule: selectedEvents[i],
                      elevator: _findElevator(
                        selectedEvents[i].elevatorId,
                        elevators,
                      ),
                      technician: _findProfile(
                        selectedEvents[i].technicianId,
                        techs,
                      ),
                      onCancel: selectedEvents[i].status == 'pending' ||
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

// ── _CalendarTaskCard ─────────────────────────────────────────────────────────

class _CalendarTaskCard extends StatelessWidget {
  const _CalendarTaskCard({
    required this.schedule,
    this.elevator,
    this.technician,
    this.onCancel,
  });

  final ScheduleModel schedule;
  final ElevatorModel? elevator;
  final ProfileModel? technician;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final pColor = _priorityColor(schedule.priority);
    final sColor = _statusColor(schedule.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Priority stripe
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: pColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: time + badges
                      Row(
                        children: [
                          Text(
                            _fmtTime(schedule.scheduledDate),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: pColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PriorityBadge(priority: schedule.priority),
                          const Spacer(),
                          _StatusBadge(
                            label: _statusLabel(schedule.status),
                            color: sColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Elevator name
                      Text(
                        elevator?.buildingName ?? 'Asansör ${schedule.elevatorId.substring(0, 6)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Address
                      if (elevator?.address != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: AppColors.outline,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  elevator!.address!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      // Technician row
                      Row(
                        children: [
                          const Icon(
                            Icons.engineering_outlined,
                            size: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            technician?.displayName ??
                                'Teknisyen ${schedule.technicianId.substring(0, 6)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (schedule.notes != null &&
                              schedule.notes!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.notes_outlined,
                              size: 13,
                              color: AppColors.outline,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                schedule.notes!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Cancel button
                      if (onCancel != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onCancel,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 14),
                            label: const Text(
                              'İptal Et',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
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
}

// ── Small badge widgets ───────────────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _priorityLabel(priority),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── _AssignTaskSheet ──────────────────────────────────────────────────────────

class _AssignTaskSheet extends ConsumerStatefulWidget {
  const _AssignTaskSheet({required this.preselectedDate});
  final DateTime preselectedDate;

  @override
  ConsumerState<_AssignTaskSheet> createState() => _AssignTaskSheetState();
}

class _AssignTaskSheetState extends ConsumerState<_AssignTaskSheet> {
  ElevatorModel? _selectedElevator;
  ProfileModel? _selectedTechnician;
  late DateTime _date;
  late TimeOfDay _time;
  String _priority = 'normal';
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = widget.preselectedDate;
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _formattedDate =>
      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';

  String get _formattedTime =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  DateTime get _scheduledDateTime => DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickElevator(List<ElevatorModel> elevators) async {
    final result = await showDialog<ElevatorModel>(
      context: context,
      builder: (_) => _ElevatorPickerDialog(
        elevators: elevators,
        selected: _selectedElevator,
      ),
    );
    if (result != null) setState(() => _selectedElevator = result);
  }

  Future<void> _pickTechnician(List<ProfileModel> techs) async {
    final result = await showDialog<ProfileModel>(
      context: context,
      builder: (_) => _TechnicianPickerDialog(
        technicians: techs,
        selected: _selectedTechnician,
      ),
    );
    if (result != null) setState(() => _selectedTechnician = result);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedElevator == null || _selectedTechnician == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen asansör ve teknisyen seçin.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await ref.read(scheduleControllerProvider.notifier).assignTask(
          elevatorId: _selectedElevator!.id,
          technicianId: _selectedTechnician!.id,
          scheduledDate: _scheduledDateTime,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          priority: _priority,
        );

    if (!mounted) return;
    final ctrl = ref.read(scheduleControllerProvider);
    if (ctrl.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ctrl.error.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görev başarıyla atandı.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final elevatorsAsync = ref.watch(elevatorsProvider);
    final techsAsync = ref.watch(profilesByRoleProvider('technician'));
    final isSubmitting = ref.watch(scheduleControllerProvider).isLoading;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Row(
                children: [
                  const Text(
                    'Yeni Görev Ata',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: AppColors.outline,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.outlineVariant),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Elevator picker ─────────────────────────────────
                      const SectionLabel(
                        icon: Icons.elevator_outlined,
                        label: 'Asansör',
                        color: AppColors.primary,
                        iconSize: 15,
                        gap: 6,
                        textStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PickerField(
                        hint: 'Asansör seçin...',
                        value: _selectedElevator?.buildingName,
                        icon: Icons.business_outlined,
                        onTap: elevatorsAsync.valueOrNull == null
                            ? null
                            : () => _pickElevator(elevatorsAsync.value!),
                        isLoading: elevatorsAsync.isLoading,
                        hasError: _selectedElevator == null,
                      ),

                      const SizedBox(height: 20),

                      // ── Technician picker ────────────────────────────────
                      const SectionLabel(
                        icon: Icons.engineering_outlined,
                        label: 'Teknisyen',
                        color: AppColors.primary,
                        iconSize: 15,
                        gap: 6,
                        textStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PickerField(
                        hint: 'Teknisyen seçin...',
                        value: _selectedTechnician?.displayName,
                        icon: Icons.person_outline,
                        onTap: techsAsync.valueOrNull == null
                            ? null
                            : () => _pickTechnician(techsAsync.value!),
                        isLoading: techsAsync.isLoading,
                        hasError: _selectedTechnician == null,
                      ),

                      const SizedBox(height: 20),

                      // ── Date & Time pickers ──────────────────────────────
                      const SectionLabel(
                        icon: Icons.calendar_today_outlined,
                        label: 'Tarih ve Saat',
                        color: AppColors.primary,
                        iconSize: 15,
                        gap: 6,
                        textStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _PickerField(
                              hint: 'Tarih',
                              value: _formattedDate,
                              icon: Icons.today_outlined,
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PickerField(
                              hint: 'Saat',
                              value: _formattedTime,
                              icon: Icons.access_time_outlined,
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Priority selector ────────────────────────────────
                      const SectionLabel(
                        icon: Icons.flag_outlined,
                        label: 'Öncelik',
                        color: AppColors.primary,
                        iconSize: 15,
                        gap: 6,
                        textStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PrioritySelector(
                        selected: _priority,
                        onChanged: (p) => setState(() => _priority = p),
                      ),

                      const SizedBox(height: 20),

                      // ── Notes ────────────────────────────────────────────
                      const SectionLabel(
                        icon: Icons.notes_outlined,
                        label: 'Notlar (İsteğe Bağlı)',
                        color: AppColors.primary,
                        iconSize: 15,
                        gap: 6,
                        textStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              'Görev hakkında ek bilgi veya talimatlar...',
                          hintStyle: const TextStyle(
                            color: AppColors.outline,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.outlineVariant, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Submit button ────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.assignment_turned_in_outlined),
                          label: Text(
                            isSubmitting ? 'Atanıyor...' : 'Görevi Ata',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _PrioritySelector ─────────────────────────────────────────────────────────

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  static const _priorities = [
    ('low', 'Düşük', Icons.arrow_downward_rounded),
    ('normal', 'Normal', Icons.remove_rounded),
    ('high', 'Yüksek', Icons.arrow_upward_rounded),
    ('emergency', 'Acil', Icons.warning_amber_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _priorities.map((entry) {
        final (value, label, icon) = entry;
        final isSelected = selected == value;
        final color = _priorityColor(value);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.12)
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : AppColors.outlineVariant,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? color : AppColors.outline,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? color : AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── _PickerField ──────────────────────────────────────────────────────────────

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.hint,
    required this.icon,
    required this.onTap,
    this.value,
    this.isLoading = false,
    this.hasError = false,
  });

  final String hint;
  final String? value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue ? AppColors.primary.withValues(alpha: 0.5) : AppColors.outlineVariant,
            width: hasValue ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: hasValue ? AppColors.primary : AppColors.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isLoading
                  ? const SizedBox(
                      height: 14,
                      child: LinearProgressIndicator(),
                    )
                  : Text(
                      hasValue ? value! : hint,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            hasValue ? FontWeight.w600 : FontWeight.w400,
                        color: hasValue ? AppColors.onSurface : AppColors.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: hasValue ? AppColors.primary : AppColors.outline,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _ElevatorPickerDialog ─────────────────────────────────────────────────────

class _ElevatorPickerDialog extends StatefulWidget {
  const _ElevatorPickerDialog({
    required this.elevators,
    this.selected,
  });

  final List<ElevatorModel> elevators;
  final ElevatorModel? selected;

  @override
  State<_ElevatorPickerDialog> createState() => _ElevatorPickerDialogState();
}

class _ElevatorPickerDialogState extends State<_ElevatorPickerDialog> {
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<ElevatorModel> get _filtered {
    if (_query.isEmpty) return widget.elevators;
    final q = _query.toLowerCase();
    return widget.elevators.where((e) {
      return e.buildingName.toLowerCase().contains(q) ||
          (e.address ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Asansör Seç',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Bina adı veya adres ara...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.outline),
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final e = _filtered[i];
                  final isSelected = widget.selected?.id == e.id;
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.elevator_outlined,
                        size: 18,
                        color: isSelected ? AppColors.primary : AppColors.outline,
                      ),
                    ),
                    title: Text(
                      e.buildingName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : AppColors.onSurface,
                      ),
                    ),
                    subtitle: e.address != null
                        ? Text(
                            e.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontSize: 12, color: AppColors.outline),
                          )
                        : null,
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(context, e),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}

// ── _TechnicianPickerDialog ───────────────────────────────────────────────────

class _TechnicianPickerDialog extends StatefulWidget {
  const _TechnicianPickerDialog({
    required this.technicians,
    this.selected,
  });

  final List<ProfileModel> technicians;
  final ProfileModel? selected;

  @override
  State<_TechnicianPickerDialog> createState() =>
      _TechnicianPickerDialogState();
}

class _TechnicianPickerDialogState extends State<_TechnicianPickerDialog> {
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<ProfileModel> get _filtered {
    if (_query.isEmpty) return widget.technicians;
    final q = _query.toLowerCase();
    return widget.technicians.where((p) {
      return (p.fullName ?? '').toLowerCase().contains(q) ||
          (p.email ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Teknisyen Seç',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ad veya e-posta ara...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.outline),
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.technicians.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz kayıtlı teknisyen yok.',
                  style: TextStyle(color: AppColors.outline),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final p = _filtered[i];
                    final isSelected = widget.selected?.id == p.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceContainer,
                        radius: 18,
                        child: Text(
                          p.initials,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.onSurface,
                          ),
                        ),
                      ),
                      title: Text(
                        p.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : AppColors.onSurface,
                        ),
                      ),
                      subtitle: p.phone != null
                          ? Text(
                              p.phone!,
                              style:
                                  const TextStyle(fontSize: 12, color: AppColors.outline),
                            )
                          : null,
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}

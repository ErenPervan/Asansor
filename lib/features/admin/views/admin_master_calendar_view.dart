import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import 'package:table_calendar/table_calendar.dart';

import '../models/schedule_with_details.dart';

import '../providers/admin_providers.dart';

import '../../../core/theme/app_colors.dart';

// Dot colours for calendar markers.
const _dotRed = Color(0xFFDC2626);
const _dotGreen = Color(0xFF16A34A);
const _dotAmber = Color(0xFFD97706);

// ─────────────────────────────────────────────────────────────────────────────

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
    final allAsync = ref.watch(allSchedulesWithDetailsProvider);
    final filter = ref.watch(masterCalendarFilterProvider);

    // Listen for auto-schedule results to show the result Snackbar.
    ref.listen(autoScheduleControllerProvider, (prev, next) {
      next.whenOrNull(
        data: (result) {
          if (result == null) return;
          final msg = result.inserted > 0
              ? '${result.inserted} adet asansörün bakımı takvime eklendi! ✅'
              : 'Bu ay için tüm periyodik bakımlar zaten mevcut.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
              backgroundColor: result.inserted > 0
                  ? const Color(0xFF166534)
                  : const Color(0xFF475569),
              duration: const Duration(seconds: 4),
            ),
          );
        },
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    });

    final autoScheduleState = ref.watch(autoScheduleControllerProvider);
    final isGenerating = autoScheduleState.isLoading;

    return Scaffold(
      backgroundColor: AppThemeColors.of(context).background,
      appBar: AppBar(
        title: const Text(
          'Ana Takvim',
          style: TextStyle(fontWeight: FontWeight.w800),
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
                          color: Color(0xFFEF4444),
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
      // ── FAB: "Bu Ayı Planla" ──────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isGenerating
            ? null
            : () => _confirmAutoSchedule(context, _focusedDay),
        icon: isGenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_fix_high_rounded),
        label: Text(
          isGenerating ? 'Oluşturuluyor…' : 'Bu Ayı Planla',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: isGenerating ? AppColors.outline : AppColors.primary,
      ),
      body: allAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
              // ── Calendar ────────────────────────────────────────────
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

              const Divider(height: 1, color: AppColors.outlineVariant),

              // ── Day header ──────────────────────────────────────────
              _DayHeader(day: _selectedDay, taskCount: dayTasks.length),

              // ── Task list ───────────────────────────────────────────
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
    final monthLabel = DateFormat('MMMM y', 'tr_TR').format(month);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_fix_high_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Otomatik Planlama',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          '$monthLabel ayı için eksik olan tüm periyodik bakımlar '
          'otomatik oluşturulacak.\n\n'
          'Onaylıyor musunuz?',
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'İptal',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
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

  // ── Pure helpers ────────────────────────────────────────────────────────

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
      result = result.where((s) => s.status == filter.status).toList();
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

// ── Calendar section ──────────────────────────────────────────────────────────

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
    return Container(
      color: AppColors.surface,
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
        // ── Style ──────────────────────────────────────────────────────
        calendarStyle: CalendarStyle(
          // Selected day: solid crimson circle with white text.
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          // Today: crimson border, no fill.
          todayDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          todayTextStyle: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
          defaultDecoration: const BoxDecoration(shape: BoxShape.circle),
          weekendDecoration: const BoxDecoration(shape: BoxShape.circle),
          weekendTextStyle: const TextStyle(color: AppColors.onSurfaceVariant),
          outsideDaysVisible: false,
          cellMargin: const EdgeInsets.all(5),
          // Marker decoration is overridden by calendarBuilders below.
          markerDecoration: const BoxDecoration(shape: BoxShape.circle),
          markersMaxCount: 1,
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: AppColors.primary,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: AppColors.primary,
          ),
          headerPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
          weekendStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.outline,
          ),
        ),
        // ── Marker builder ─────────────────────────────────────────────
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
  /// RED  → ≥1 emergency/high non-completed task.
  /// GREEN → all active tasks are completed.
  /// AMBER → ≥1 pending/in-progress task.
  static Color? _markerColor(List<ScheduleWithDetails> events) {
    final active = events.where((e) => e.status != 'cancelled').toList();
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

// ── Day header ────────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.taskCount});

  final DateTime day;
  final int taskCount;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('d MMMM y, EEEE', 'tr_TR').format(day);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surfaceContainer,
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 15,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: taskCount > 0
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$taskCount görev',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: taskCount > 0
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Task card ─────────────────────────────────────────────────────────────────

class _MasterTaskCard extends StatelessWidget {
  const _MasterTaskCard({required this.task});

  final ScheduleWithDetails task;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat(
      'HH:mm',
      'tr_TR',
    ).format(task.scheduledDate.toLocal());

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/elevator/${task.elevatorId}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Priority colour stripe
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: _priorityStripeColor(task.priority),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
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
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusIcon(status: task.status),
                          ],
                        ),

                        // Address
                        if (task.address != null &&
                            task.address!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: AppColors.outline,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  task.address!,
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
                        ],

                        const SizedBox(height: 8),

                        // Technician row
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                task.technicianName.isNotEmpty
                                    ? task.technicianName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                task.technicianName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Time + badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: AppColors.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            _PriorityBadge(priority: task.priority),
                            _TaskStatusBadge(status: task.status),
                            if (task.isPeriodicMaintenance)
                              const _Badge(
                                label: 'PERİYODİK',
                                bg: Color(0xFFEDE9FE),
                                fg: Color(0xFF5B21B6),
                              ),
                          ],
                        ),

                        // Notes
                        if (task.notes != null && task.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              task.notes!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
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

  static Color _priorityStripeColor(String priority) {
    switch (priority) {
      case 'emergency':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFEA580C);
      case 'normal':
        return const Color(0xFF2563EB);
      default: // low
        return const Color(0xFF94A3B8);
    }
  }
}

// ── Status icon ───────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _data(status);
    return Icon(icon, size: 18, color: color);
  }

  static (IconData, Color) _data(String s) {
    switch (s) {
      case 'completed':
        return (Icons.check_circle_rounded, Color(0xFF16A34A));
      case 'in_progress':
        return (Icons.autorenew_rounded, Color(0xFFD97706));
      case 'cancelled':
        return (Icons.cancel_rounded, Color(0xFF94A3B8));
      default: // pending
        return (Icons.schedule_rounded, Color(0xFF94A3B8));
    }
  }
}

// ── Priority badge ────────────────────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _styles(priority);
    return _Badge(label: label, bg: bg, fg: fg);
  }

  static (String, Color, Color) _styles(String p) {
    switch (p) {
      case 'emergency':
        return ('ACİL', Color(0xFFFEE2E2), Color(0xFFB91C1C));
      case 'high':
        return ('YÜKSEK', Color(0xFFFFF7ED), Color(0xFFC2410C));
      case 'low':
        return ('DÜŞÜK', Color(0xFFF1F5F9), Color(0xFF94A3B8));
      default: // normal
        return ('NORMAL', Color(0xFFF1F5F9), Color(0xFF475569));
    }
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _TaskStatusBadge extends StatelessWidget {
  const _TaskStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _styles(status);
    return _Badge(label: label, bg: bg, fg: fg);
  }

  static (String, Color, Color) _styles(String s) {
    switch (s) {
      case 'completed':
        return ('TAMAMLANDI', Color(0xFFDCFCE7), Color(0xFF166534));
      case 'in_progress':
        return ('DEVAM', Color(0xFFFFF7ED), Color(0xFF92400E));
      case 'cancelled':
        return ('İPTAL', Color(0xFFF1F5F9), Color(0xFF64748B));
      default: // pending
        return ('BEKLİYOR', Color(0xFFF1F5F9), Color(0xFF475569));
    }
  }
}

// ── Shared badge widget ───────────────────────────────────────────────────────

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
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Empty placeholder ─────────────────────────────────────────────────────────

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
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_outlined,
                size: 36,
                color: AppColors.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$label için\nplanlanmış görev yok',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'Veriler yüklenemedi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
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

// ── Filter sheet ──────────────────────────────────────────────────────────────

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

    // Build unique, alphabetically sorted technician list.
    // Skip unassigned tasks (empty technicianId) — they would otherwise show
    // up as an "Atanmamış" entry which doesn't make sense as a filter chip.
    final seen = <String>{};
    final technicians = <MapEntry<String, String>>[];
    for (final s in allSchedules) {
      if (s.technicianId.isNotEmpty && seen.add(s.technicianId)) {
        technicians.add(MapEntry(s.technicianId, s.technicianName));
      }
    }
    technicians.sort((a, b) => a.value.compareTo(b.value));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header row
              Row(
                children: [
                  const Text(
                    'Filtrele',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (filter.isActive)
                    TextButton(
                      onPressed: notifier.clear,
                      child: const Text(
                        'Temizle',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.outline),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Technician section ──────────────────────────────────
              if (technicians.isNotEmpty) ...[
                const _SheetSectionLabel('TEKNİSYEN'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // "Tümü" chip
                    _FilterChipItem(
                      label: 'Tümü',
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
                const SizedBox(height: 16),
                const Divider(color: AppColors.outlineVariant, height: 1),
                const SizedBox(height: 16),
              ],

              // ── Status section ──────────────────────────────────────
              const _SheetSectionLabel('DURUM'),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
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
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfaceVariant,
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
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      checkmarkColor: AppColors.primary,
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.4)
            : AppColors.outlineVariant,
      ),
      backgroundColor: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ── Legend row ────────────────────────────────────────────────────────────────

/// Shown at the bottom of the calendar legend (optional, not used in main UI
/// but exported so the admin can read what each dot colour means at a glance).
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: _dotRed, label: 'Acil/Yüksek'),
        const SizedBox(width: 16),
        _LegendDot(color: _dotAmber, label: 'Bekliyor'),
        const SizedBox(width: 16),
        _LegendDot(color: _dotGreen, label: 'Tamamlandı'),
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
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

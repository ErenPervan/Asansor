import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/models/schedule_with_details.dart';
import 'package:asansor/features/admin/providers/admin_providers.dart';
import 'package:asansor/features/admin/views/widgets/admin_master_calendar_workspace.dart';
import 'package:asansor/features/admin/views/widgets/admin_master_calendar_states.dart';
import 'package:asansor/features/admin/views/widgets/admin_master_calendar_sheets.dart';

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
        error: (e, st) => AdminMasterCalendarErrorView(
          error: e,
          onRetry: () => ref.invalidate(allSchedulesWithDetailsProvider),
        ),
        data: (all) {
          final filtered = _applyFilter(all, filter);
          final eventMap = _buildEventMap(filtered);
          final dayTasks = List<ScheduleWithDetails>.from(
            eventMap[_dayKey(_selectedDay)] ?? [],
          )..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

          return MasterCalendarWorkspace(
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
      builder: (_) => FilterSheet(allSchedules: all),
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

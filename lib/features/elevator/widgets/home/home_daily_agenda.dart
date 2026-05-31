import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/utils/elevator_utils.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:asansor/core/widgets/empty_state.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/admin/models/schedule_model.dart';
import 'package:asansor/features/admin/providers/admin_providers.dart';

class DailyAgendaSection extends StatelessWidget {
  const DailyAgendaSection({
    super.key,
    required this.mySchedules,
    required this.elevators,
  });

  final AsyncValue<List<ScheduleModel>> mySchedules;
  final List<ElevatorModel>? elevators;

  static bool _isToday(DateTime dt) {
    final now = DateTime.now();
    final d = dt.toLocal();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static String _fmtScheduleDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'Bugün $time';
    if (day == today.add(const Duration(days: 1))) return 'Yarın $time';
    return '${local.day}/${local.month}/${local.year} $time';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Günlük Ajanda',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                // Live dot — visible only when the stream is active
                mySchedules.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (s) => Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Content
        mySchedules.when(
          loading: () => const LoadingState(),
          error: (e, _) =>
              ErrorState(message: e.toString().replaceFirst('Exception: ', '')),
          data: (schedules) {
            if (schedules.isEmpty) {
              return const EmptyState(
                icon: Icons.event_available_outlined,
                message: 'Atanmış göreviniz bulunmuyor.',
              );
            }

            // Split into today vs upcoming
            final todayTasks = schedules
                .where((s) => _isToday(s.scheduledDate))
                .toList();
            final upcomingTasks = schedules
                .where((s) => !_isToday(s.scheduledDate))
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (todayTasks.isNotEmpty) ...[
                  AgendaGroupHeader(
                    label: "Bugün",
                    count: todayTasks.length,
                    highlight: true,
                  ),
                  const SizedBox(height: 8),
                  ...todayTasks.map(
                    (s) => AgendaTaskCard(
                      schedule: s,
                      elevator: findElevator(s.elevatorId, elevators),
                      dateLabel: _fmtScheduleDate(s.scheduledDate),
                    ),
                  ),
                ],
                if (upcomingTasks.isNotEmpty) ...[
                  if (todayTasks.isNotEmpty) const SizedBox(height: 12),
                  AgendaGroupHeader(
                    label: "Yaklaşan",
                    count: upcomingTasks.length,
                    highlight: false,
                  ),
                  const SizedBox(height: 8),
                  ...upcomingTasks
                      .take(3)
                      .map(
                        (s) => AgendaTaskCard(
                          schedule: s,
                          elevator: findElevator(s.elevatorId, elevators),
                          dateLabel: _fmtScheduleDate(s.scheduledDate),
                        ),
                      ),
                  if (upcomingTasks.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton(
                        onPressed: () => context.push('/admin/calendar'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '+${upcomingTasks.length - 3} daha görev var. Tümünü gör',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class AgendaGroupHeader extends StatelessWidget {
  const AgendaGroupHeader({
    super.key,
    required this.label,
    required this.count,
    required this.highlight,
  });

  final String label;
  final int count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.primary : AppColors.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: highlight
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.primary : AppColors.outline,
            ),
          ),
        ),
      ],
    );
  }
}

class AgendaTaskCard extends ConsumerWidget {
  const AgendaTaskCard({
    super.key,
    required this.schedule,
    required this.elevator,
    required this.dateLabel,
  });

  final ScheduleModel schedule;
  final ElevatorModel? elevator;
  final String dateLabel;

  static Color _priorityColor(String p) {
    switch (p) {
      case 'low':
        return const Color(0xFF78909C);
      case 'high':
        return const Color(0xFFE65100);
      case 'emergency':
        return const Color(0xFFBA1A1A);
      default:
        return AppColors.primary;
    }
  }

  static String _priorityLabel(String p) {
    switch (p) {
      case 'low':
        return 'Düşük';
      case 'high':
        return 'Yüksek';
      case 'emergency':
        return '⚠️ Acil';
      default:
        return 'Normal';
    }
  }

  static bool _isActive(String s) => s == 'pending' || s == 'in_progress';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pColor = _priorityColor(schedule.priority);
    final isEmergency = schedule.priority == 'emergency';
    final shortElevatorId = schedule.elevatorId.length > 6
        ? schedule.elevatorId.substring(0, 6)
        : schedule.elevatorId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isEmergency
              ? const Color(0xFFFFDAD6).withValues(alpha: 0.4)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEmergency
                ? const Color(0xFFBA1A1A).withValues(alpha: 0.3)
                : AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
                width: 4,
                decoration: BoxDecoration(
                  color: pColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time + priority badge
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_outlined,
                            size: 13,
                            color: pColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: pColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: pColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _priorityLabel(schedule.priority),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: pColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Building name
                      Text(
                        elevator?.buildingName ?? 'Asansör $shortElevatorId',
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
                                size: 12,
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
                      if (schedule.notes != null && schedule.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            schedule.notes!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 10),
                      // İşe Başla button — only for active tasks
                      if (_isActive(schedule.status))
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: FilledButton.icon(
                            onPressed: () {
                              // Mark in_progress then open elevator hub
                              if (schedule.status == 'pending') {
                                ref
                                    .read(scheduleControllerProvider.notifier)
                                    .updateStatus(
                                      taskId: schedule.id,
                                      status: 'in_progress',
                                    );
                              }
                              context.push('/elevator/${schedule.elevatorId}');
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: pColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'İşe Başla',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              schedule.status == 'completed'
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              size: 14,
                              color: schedule.status == 'completed'
                                  ? const Color(0xFF2E7D32)
                                  : AppColors.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              schedule.status == 'completed'
                                  ? 'Tamamlandı'
                                  : 'İptal Edildi',
                              style: TextStyle(
                                fontSize: 12,
                                color: schedule.status == 'completed'
                                    ? const Color(0xFF2E7D32)
                                    : AppColors.outline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

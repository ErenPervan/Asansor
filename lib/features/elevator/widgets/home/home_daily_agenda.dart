import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/enums/app_enums.dart';
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
                Text(
                  'Günlük Ajanda',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppThemeColors.of(context).onSurface,
                    letterSpacing: 0.0,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Live dot — visible only when the stream is active
                mySchedules.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (s) => Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppThemeColors.of(context).success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Content
        mySchedules.when(
          loading: () => const LoadingState(shrinkWrap: true),
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
                  const SizedBox(height: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.sm),
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
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppThemeColors.of(context).primary,
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
    final colors = AppThemeColors.of(context);
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: highlight ? colors.primary : colors.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: highlight
                ? colors.primary.withValues(alpha: 0.1)
                : colors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? colors.primary : colors.outline,
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

  static Color _priorityColor(String p, AppThemeColors colors) {
    switch (p) {
      case 'low':
        return colors.outline;
      case 'high':
        return colors.warning;
      case 'emergency':
        return colors.error;
      default:
        return colors.primary;
    }
  }

  static Widget _buildPriorityLabel(
    String p,
    Color color,
    TextTheme textTheme,
  ) {
    final style = textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: color,
    );
    if (p == 'emergency') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_rounded, size: 10, color: color),
          const SizedBox(width: 2),
          Text('Acil', style: style),
        ],
      );
    }
    final label = switch (p) {
      'low' => 'Düşük',
      'high' => 'Yüksek',
      _ => 'Normal',
    };
    return Text(label, style: style);
  }

  static bool _isActive(ScheduleStatus s) =>
      s == ScheduleStatus.pending || s == ScheduleStatus.inProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final pColor = _priorityColor(schedule.priority, colors);
    final isEmergency = schedule.priority == 'emergency';
    final shortElevatorId = schedule.elevatorId.length > 6
        ? schedule.elevatorId.substring(0, 6)
        : schedule.elevatorId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isEmergency
              ? colors.errorContainer.withValues(alpha: 0.4)
              : colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEmergency
                ? colors.error.withValues(alpha: 0.3)
                : colors.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.onSurface.withValues(alpha: 0.03),
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
                            style: textTheme.labelMedium?.copyWith(
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
                            child: _buildPriorityLabel(
                              schedule.priority,
                              pColor,
                              textTheme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Building name
                      Text(
                        elevator?.buildingName ?? 'Asansör $shortElevatorId',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
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
                              Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: colors.outline,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  elevator!.address!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.outline,
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
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
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
                              if (schedule.status == ScheduleStatus.pending) {
                                ref
                                    .read(scheduleControllerProvider.notifier)
                                    .updateStatus(
                                      taskId: schedule.id,
                                      status: ScheduleStatus.inProgress,
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
                            label: Text(
                              'İşe Başla',
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              schedule.status == ScheduleStatus.completed
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              size: 14,
                              color: schedule.status == ScheduleStatus.completed
                                  ? colors.success
                                  : colors.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              schedule.status == ScheduleStatus.completed
                                  ? 'Tamamlandı'
                                  : 'İptal Edildi',
                              style: textTheme.labelMedium?.copyWith(
                                color:
                                    schedule.status == ScheduleStatus.completed
                                    ? colors.success
                                    : colors.outline,
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

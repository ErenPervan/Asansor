import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/schedule_with_details.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:asansor/features/admin/widgets/master_calendar/master_calendar_constants.dart';

class MasterCalendarSelectedDayPanel extends StatelessWidget {
  const MasterCalendarSelectedDayPanel({
    super.key,
    required this.day,
    required this.tasks,
  });

  final DateTime day;
  final List<ScheduleWithDetails> tasks;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final title = DateFormat('d MMMM Görevleri', 'tr_TR').format(day);
    final fullDate = DateFormat('EEEE, d MMMM y', 'tr_TR').format(day);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MasterCalendarConstants.line),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fullDate,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _CountBadge(count: tasks.length),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: colors.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          if (tasks.isEmpty)
            _EmptyDayPlaceholder(day: day)
          else
            Column(
              children: [
                for (var i = 0; i < tasks.length; i++) ...[
                  _MasterTaskCard(task: tasks[i]),
                  if (i != tasks.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: count > 0
            ? colors.primary.withValues(alpha: 0.1)
            : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count görev',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: count > 0 ? colors.primary : colors.onSurfaceVariant,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

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
      color: colors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/elevator/${task.elevatorId}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MasterCalendarConstants.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _priorityColor(context, task.priority),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _taskIconColor(context, task).$1,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _taskIcon(task),
                              color: _taskIconColor(context, task).$2,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.buildingName,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colors.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (task.address != null &&
                                    task.address!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    task.address!,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.outline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          _MiniInfo(
                            icon: Icons.person_rounded,
                            label: task.technicianName.isEmpty
                                ? 'Atanmamış'
                                : task.technicianName,
                          ),
                          _MiniInfo(icon: Icons.schedule_rounded, label: time),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
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
                      if (task.notes != null && task.notes!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          task.notes!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  static Color _priorityColor(BuildContext context, String priority) {
    final colors = AppThemeColors.of(context);
    switch (priority) {
      case 'emergency':
        return colors.error;
      case 'high':
        return colors.warning;
      case 'low':
        return colors.outline;
      default:
        return colors.primary;
    }
  }

  static IconData _taskIcon(ScheduleWithDetails task) {
    if (task.priority == 'emergency' || task.priority == 'high') {
      return Icons.warning_rounded;
    }
    if (task.isCompleted) return Icons.check_rounded;
    return Icons.build_rounded;
  }

  static (Color, Color) _taskIconColor(
    BuildContext context,
    ScheduleWithDetails task,
  ) {
    final colors = AppThemeColors.of(context);
    if (task.priority == 'emergency' || task.priority == 'high') {
      return (colors.errorContainer, colors.error);
    }
    if (task.isCompleted) {
      return (colors.successContainer, colors.success);
    }
    return (colors.primaryContainer, colors.primary);
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.outline),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

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
        return ('ACİL', colors.errorContainer, colors.error);
      case 'high':
        return ('YÜKSEK', colors.warningContainer, colors.warning);
      case 'low':
        return ('DÜŞÜK', colors.surfaceContainerHigh, colors.onSurfaceVariant);
      default:
        return ('NORMAL', colors.surfaceContainer, colors.onSurface);
    }
  }
}

class _TaskStatusBadge extends StatelessWidget {
  const _TaskStatusBadge({required this.status});

  final ScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _styles(context, status);
    return _Badge(label: label, bg: bg, fg: fg);
  }

  static (String, Color, Color) _styles(
    BuildContext context,
    ScheduleStatus status,
  ) {
    final colors = AppThemeColors.of(context);
    switch (status) {
      case ScheduleStatus.completed:
        return ('TAMAMLANDI', colors.successContainer, colors.success);
      case ScheduleStatus.inProgress:
        return ('DEVAM', colors.warningContainer, colors.warning);
      case ScheduleStatus.cancelled:
        return ('İPTAL', colors.surfaceContainerHigh, colors.onSurfaceVariant);
      case ScheduleStatus.pending:
        return ('BEKLİYOR', colors.surfaceContainer, colors.onSurface);
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: fg,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EmptyDayPlaceholder extends StatelessWidget {
  const _EmptyDayPlaceholder({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final label = DateFormat('d MMMM', 'tr_TR').format(day);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.event_available_outlined,
                size: 34,
                color: colors.outline,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '$label için planlanmış görev yok',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

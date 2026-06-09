import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/technician_stats.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:asansor/features/admin/widgets/technician_management/technician_management_shared.dart';

void showDetailSheet(BuildContext context, TechnicianStats stats) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TechnicianDetailSheet(stats: stats),
  );
}

class TechnicianDetailSheet extends StatelessWidget {
  const TechnicianDetailSheet({super.key, required this.stats});

  final TechnicianStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.36,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: panelLine),
            boxShadow: [
              BoxShadow(
                color: colors.onSurface.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: colors.primary.withValues(alpha: 0.10),
                      child: Text(
                        stats.profile.initials,
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stats.profile.displayName,
                            style: textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            stats.todayTotal == 0
                                ? 'Bugün görev yok'
                                : '${stats.todayTotal} görev, ${stats.todayCompleted} tamamlandı',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: colors.outline),
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 24, color: colors.outlineVariant),
              Expanded(
                child: stats.todayTasks.isEmpty
                    ? _SheetEmptyView(name: stats.profile.displayName)
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: stats.todayTasks.length,
                        itemBuilder: (_, i) => _TimelineTaskItem(
                          task: stats.todayTasks[i],
                          isLast: i == stats.todayTasks.length - 1,
                          onNavigate: () {
                            Navigator.of(context).pop();
                            context.push(
                              '/elevator/${stats.todayTasks[i].elevatorId}',
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineTaskItem extends StatelessWidget {
  const _TimelineTaskItem({
    required this.task,
    required this.isLast,
    required this.onNavigate,
  });

  final TechnicianTask task;
  final bool isLast;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final time = DateFormat(
      'HH:mm',
      'tr_TR',
    ).format(task.scheduledTime.toLocal());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 58,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: task.isCompleted
                        ? colors.successContainer
                        : colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    time,
                    style: textTheme.labelSmall?.copyWith(
                      color: task.isCompleted ? colors.success : colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: colors.outlineVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Material(
                color: colors.background,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onNavigate,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: panelLine),
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
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.buildingName,
                                  style: textTheme.labelLarge?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (task.address != null &&
                                    task.address!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    task.address!,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colors.outline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (task.notes != null &&
                                    task.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    task.notes!,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _SmallBadge.status(context, task.status),
                                    _SmallBadge.priority(
                                      context,
                                      task.priority,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: colors.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
      case 'normal':
        return colors.primary;
      default:
        return colors.outline;
    }
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  factory _SmallBadge.status(BuildContext context, ScheduleStatus status) {
    final colors = AppThemeColors.of(context);
    switch (status) {
      case ScheduleStatus.completed:
        return _SmallBadge(
          label: 'TAMAMLANDI',
          bg: colors.successContainer,
          fg: colors.success,
        );
      case ScheduleStatus.inProgress:
        return _SmallBadge(
          label: 'DEVAM',
          bg: colors.warningContainer,
          fg: colors.warning,
        );
      case ScheduleStatus.cancelled:
        return _SmallBadge(
          label: 'İPTAL',
          bg: colors.surfaceContainerHigh,
          fg: colors.onSurfaceVariant,
        );
      case ScheduleStatus.pending:
        return _SmallBadge(
          label: 'BEKLİYOR',
          bg: colors.surfaceContainer,
          fg: colors.onSurface,
        );
    }
  }

  factory _SmallBadge.priority(BuildContext context, String priority) {
    final colors = AppThemeColors.of(context);
    switch (priority) {
      case 'emergency':
        return _SmallBadge(
          label: 'ACİL',
          bg: colors.errorContainer,
          fg: colors.error,
        );
      case 'high':
        return _SmallBadge(
          label: 'YÜKSEK',
          bg: colors.warningContainer,
          fg: colors.warning,
        );
      case 'low':
        return _SmallBadge(
          label: 'DÜŞÜK',
          bg: colors.surfaceContainerHigh,
          fg: colors.onSurfaceVariant,
        );
      default:
        return _SmallBadge(
          label: 'NORMAL',
          bg: colors.surfaceContainer,
          fg: colors.onSurface,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: fg,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SheetEmptyView extends StatelessWidget {
  const _SheetEmptyView({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 38,
              color: colors.outline,
            ),
            const SizedBox(height: 12),
            Text(
              '$name için bugün planlanmış görev yok',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

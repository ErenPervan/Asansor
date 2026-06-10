import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/models/technician_stats.dart';
import 'package:asansor/features/admin/providers/admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _panelLine = Color(0xFFE1E8F0);

class TechnicianManagementView extends ConsumerWidget {
  const TechnicianManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final dataAsync = ref.watch(technicianManagementProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Icon(Icons.elevator_rounded, color: colors.primary),
            const SizedBox(width: 10),
            Text(
              'Asansör',
              style: textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              'Operasyon Yönetimi',
              style: textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(technicianManagementProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dataAsync.when(
        loading: () => const LoadingState(),
        error: (e, st) => _ErrorBody(
          error: e,
          onRetry: () => ref.invalidate(technicianManagementProvider),
        ),
        data: (stats) => _TechnicianWorkspace(
          stats: stats,
          onRefresh: () => ref.invalidate(technicianManagementProvider),
        ),
      ),
    );
  }
}

class _TechnicianWorkspace extends StatelessWidget {
  const _TechnicianWorkspace({required this.stats, required this.onRefresh});

  final List<TechnicianStats> stats;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const _EmptyBody();

    final activeCount = stats.where((s) => s.hasActiveTasks).length;
    final freeCount = stats.length - activeCount;
    final todayTasks = stats.fold<int>(0, (sum, s) => sum + s.todayTotal);
    final completedToday = stats.fold<int>(
      0,
      (sum, s) => sum + s.todayCompleted,
    );

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PageHeader(onRefresh: onRefresh),
                  const SizedBox(height: AppSpacing.lg),
                  _MetricGrid(
                    total: stats.length,
                    active: activeCount,
                    free: freeCount,
                    todayTasks: todayTasks,
                    completedToday: completedToday,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Column(
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        _TechnicianRowCard(
                          stats: stats[i],
                          onOpenTasks: () =>
                              _showDetailSheet(context, stats[i]),
                        ),
                        if (i != stats.length - 1)
                          const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context, TechnicianStats stats) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TechnicianDetailSheet(stats: stats),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Flex(
          direction: compact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: compact
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: compact ? 0 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teknisyenler',
                    style: textTheme.headlineSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Operasyonel saha ekibi yönetimi ve anlık görev takibi.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (compact) const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              label: const Text('Yenile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                backgroundColor: colors.surface,
                side: const BorderSide(color: _panelLine),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.total,
    required this.active,
    required this.free,
    required this.todayTasks,
    required this.completedToday,
  });

  final int total;
  final int active;
  final int free;
  final int todayTasks;
  final int completedToday;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _MetricCard(
          label: 'Toplam Personel',
          value: total.toString(),
          icon: Icons.groups_rounded,
          color: AppColors.primary,
        ),
        _MetricCard(
          label: 'Sahada Aktif',
          value: active.toString(),
          icon: Icons.engineering_rounded,
          color: AppColors.skyBlue,
        ),
        _MetricCard(
          label: 'Müsait',
          value: free.toString(),
          icon: Icons.check_circle_rounded,
          color: AppColors.accentGold,
        ),
        _MetricCard(
          label: 'Bugün Tamamlanan',
          value: '$completedToday/$todayTasks',
          icon: Icons.task_alt_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 250,
      height: 118,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelLine),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianRowCard extends StatelessWidget {
  const _TechnicianRowCard({required this.stats, required this.onOpenTasks});

  final TechnicianStats stats;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final profile = stats.profile;
    final isBusy = stats.hasActiveTasks;
    final allDone = stats.todayTotal > 0 && stats.progressValue >= 1.0;
    final statusColor = isBusy
        ? colors.primary
        : allDone
        ? colors.success
        : colors.successLight;
    final statusLabel = isBusy
        ? 'Görevde'
        : allDone
        ? 'Tamamladı'
        : 'Müsait';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpenTasks,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _panelLine),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.05),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;

              final identity = _TechnicianIdentity(
                initials: profile.initials,
                name: profile.displayName,
                email: profile.email,
                phone: profile.phone,
                active: isBusy,
              );
              final status = _TechnicianStatusChips(
                statusLabel: statusLabel,
                statusColor: statusColor,
                todayTotal: stats.todayTotal,
                todayPending: stats.todayPending,
                monthlyCompleted: stats.monthlyCompleted,
              );
              final actions = _TechnicianActions(
                stats: stats,
                onOpenTasks: onOpenTasks,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: AppSpacing.md),
                    status,
                    const SizedBox(height: AppSpacing.md),
                    _ProgressLine(stats: stats),
                    const SizedBox(height: AppSpacing.md),
                    actions,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: identity),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 3, child: status),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 2, child: _ProgressLine(stats: stats)),
                  const SizedBox(width: AppSpacing.lg),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TechnicianIdentity extends StatelessWidget {
  const _TechnicianIdentity({
    required this.initials,
    required this.name,
    required this.email,
    required this.phone,
    required this.active,
  });

  final String initials;
  final String name;
  final String? email;
  final String? phone;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: colors.primary.withValues(alpha: 0.10),
              child: Text(
                initials,
                style: textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: active ? colors.success : colors.outline,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                phone == null || phone!.isEmpty
                    ? email ?? 'İletişim bilgisi yok'
                    : phone!,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (email != null && email!.isNotEmpty && phone != null) ...[
                const SizedBox(height: 2),
                Text(
                  email!,
                  style: textTheme.labelSmall?.copyWith(
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
    );
  }
}

class _TechnicianStatusChips extends StatelessWidget {
  const _TechnicianStatusChips({
    required this.statusLabel,
    required this.statusColor,
    required this.todayTotal,
    required this.todayPending,
    required this.monthlyCompleted,
  });

  final String statusLabel;
  final Color statusColor;
  final int todayTotal;
  final int todayPending;
  final int monthlyCompleted;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ChipPill(icon: Icons.circle, label: statusLabel, color: statusColor),
        _ChipPill(
          icon: Icons.assignment_rounded,
          label: 'Bugün $todayTotal görev',
          color: colors.primary,
        ),
        _ChipPill(
          icon: Icons.hourglass_top_rounded,
          label: todayPending == 0 ? 'Bekleyen yok' : '$todayPending bekliyor',
          color: todayPending == 0 ? colors.success : colors.warning,
        ),
        _ChipPill(
          icon: Icons.calendar_month_rounded,
          label: 'Bu ay $monthlyCompleted iş',
          color: AppColors.accentGold,
        ),
      ],
    );
  }
}

class _ChipPill extends StatelessWidget {
  const _ChipPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: icon == Icons.circle ? 8 : 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
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

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.stats});

  final TechnicianStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final done = stats.todayTotal > 0 && stats.progressValue >= 1;
    final progressColor = done ? colors.success : colors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Bugün',
              style: textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              stats.todayTotal == 0
                  ? '-'
                  : '${stats.todayCompleted}/${stats.todayTotal}',
              style: textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: stats.progressValue,
            minHeight: 8,
            backgroundColor: colors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          stats.todayTotal == 0
              ? 'Bugün planlanmış görev yok'
              : done
              ? 'Tüm görevler tamamlandı'
              : '${stats.todayPending} görev bekliyor',
          style: textTheme.labelSmall?.copyWith(
            color: done ? colors.success : colors.outline,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TechnicianActions extends StatelessWidget {
  const _TechnicianActions({required this.stats, required this.onOpenTasks});

  final TechnicianStats stats;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final profile = stats.profile;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconAction(
          icon: Icons.call_rounded,
          tooltip: 'Telefonu kopyala',
          onTap: () => _copyPhone(context, profile.phone, profile.displayName),
        ),
        const SizedBox(width: 8),
        _IconAction(
          icon: Icons.chat_rounded,
          tooltip: 'Mesaj için numarayı kopyala',
          onTap: () => _copyPhone(context, profile.phone, profile.displayName),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onOpenTasks,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(96, 40),
          ),
          child: Text(
            stats.todayTotal > 0 ? '${stats.todayTotal} Görev' : 'Görevler',
          ),
        ),
      ],
    );
  }

  void _copyPhone(BuildContext context, String? phone, String name) {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name için telefon numarası kayıtlı değil.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name: $phone kopyalandı.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            shape: BoxShape.circle,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Icon(icon, color: colors.secondary, size: 19),
        ),
      ),
    );
  }
}

class _TechnicianDetailSheet extends StatelessWidget {
  const _TechnicianDetailSheet({required this.stats});

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
            border: Border.all(color: _panelLine),
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
                      border: Border.all(color: _panelLine),
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

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.engineering_rounded,
                size: 42,
                color: colors.outline,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Henüz teknisyen kaydı yok',
              style: textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Kullanıcı yönetiminden teknisyen rolü atayın.',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

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
            Icon(Icons.cloud_off_outlined, size: 48, color: colors.outline),
            const SizedBox(height: 12),
            Text(
              'Veriler yüklenemedi',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
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

import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/models/technician_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:asansor/features/admin/widgets/technician_management/technician_management_shared.dart';

class TechnicianRowCard extends StatelessWidget {
  const TechnicianRowCard({super.key, required this.stats, required this.onOpenTasks});

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
            border: Border.all(color: panelLine),
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
        _ChipPill(
          icon: Icons.circle,
          label: statusLabel,
          color: statusColor,
        ),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

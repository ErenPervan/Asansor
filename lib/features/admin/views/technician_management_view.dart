import 'package:asansor/core/widgets/loading_state.dart';
import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import '../../../core/enums/app_enums.dart';

import '../models/technician_stats.dart';

import '../providers/admin_providers.dart';

import '../../../core/theme/app_colors.dart';
// â”€â”€ Main view â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
        title: Text(
          'Teknisyen Ekibi',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(technicianManagementProvider),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const LoadingState(),
        error: (e, st) => _ErrorBody(
          error: e,
          onRetry: () => ref.invalidate(technicianManagementProvider),
        ),
        data: (stats) => _TechnicianList(stats: stats),
      ),
    );
  }
}

// â”€â”€ List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TechnicianList extends StatelessWidget {
  const _TechnicianList({required this.stats});

  final List<TechnicianStats> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const _EmptyBody();
    }

    final activeCount = stats.where((s) => s.hasActiveTasks).length;
    final freeCount = stats.length - activeCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          final rowCount = (stats.length / 2).ceil();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: rowCount + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SummaryHeader(
                    total: stats.length,
                    active: activeCount,
                    free: freeCount,
                  ),
                );
              }
              final rowIndex = i - 1;
              final idx1 = rowIndex * 2;
              final idx2 = rowIndex * 2 + 1;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TechnicianCard(
                        stats: stats[idx1],
                        onTap: () => _showDetailSheet(context, stats[idx1]),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: idx2 < stats.length
                          ? _TechnicianCard(
                              stats: stats[idx2],
                              onTap: () =>
                                  _showDetailSheet(context, stats[idx2]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: stats.length + 1, // +1 for header
          separatorBuilder: (_, i) => i == 0
              ? const SizedBox(height: AppSpacing.md)
              : const SizedBox(height: 12),
          itemBuilder: (_, i) {
            if (i == 0) {
              return _SummaryHeader(
                total: stats.length,
                active: activeCount,
                free: freeCount,
              );
            }
            final techStats = stats[i - 1];
            return _TechnicianCard(
              stats: techStats,
              onTap: () => _showDetailSheet(context, techStats),
            );
          },
        );
      },
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

// â”€â”€ Summary header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.total,
    required this.active,
    required this.free,
  });

  final int total;
  final int active;
  final int free;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatPill(label: 'Toplam', value: total, light: true),
          const SizedBox(width: 12),
          _StatPill(
            label: 'Aktif',
            value: active,
            light: true,
            accent: colors.successLight,
          ),
          const SizedBox(width: 12),
          _StatPill(
            label: 'MÃ¼sait',
            value: free,
            light: true,
            accent: colors.warningLight,
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('d MMMM', 'tr_TR').format(DateTime.now()),
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'BugÃ¼n',
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    this.light = false,
    this.accent,
  });

  final String label;
  final int value;
  final bool light;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: accent ?? Colors.white,
          ),
        ),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Technician card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({required this.stats, required this.onTap});

  final TechnicianStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final profile = stats.profile;
    final allDone = stats.todayTotal > 0 && stats.progressValue >= 1.0;
    final barColor = allDone ? colors.success : colors.primary;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colors.onSurface.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // â”€â”€ Top row: avatar + info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar with status dot
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: colors.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: Text(
                            profile.initials,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: stats.hasActiveTasks
                                  ? colors.success
                                  : colors.outline,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Name + contact
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  profile.displayName,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colors.onSurface,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _MonthlyBadge(
                                count: stats.monthlyCompleted,
                                colors: colors,
                                textTheme: textTheme,
                              ),
                            ],
                          ),
                          if (profile.email != null &&
                              profile.email!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: 12,
                                  color: colors.outline,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    profile.email!,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colors.outline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (profile.phone != null &&
                              profile.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 12,
                                  color: colors.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  profile.phone!,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.outline,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // â”€â”€ Workload bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (stats.todayTotal > 0) ...[
                  Row(
                    children: [
                      Text(
                        'BugÃ¼nkÃ¼ Ä°lerleme',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${stats.todayCompleted}/${stats.todayTotal} gÃ¶rev',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stats.progressValue,
                      minHeight: 7,
                      backgroundColor: colors.outlineVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    allDone
                        ? 'âœ“ TÃ¼m gÃ¶revler tamamlandÄ±'
                        : '${stats.todayPending} gÃ¶rev bekliyor',
                    style: textTheme.labelSmall?.copyWith(
                      color: allDone ? colors.success : colors.outline,
                      fontWeight: allDone ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ] else
                  Text(
                    'BugÃ¼n iÃ§in planlanmÄ±ÅŸ gÃ¶rev yok',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                Divider(height: 20, color: colors.outlineVariant),

                // â”€â”€ Action buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Row(
                  children: [
                    _ActionButton(
                      icon: Icons.phone_outlined,
                      label: 'Ara',
                      colors: colors,
                      textTheme: textTheme,
                      onTap: () => _handleCall(
                        context,
                        profile.phone,
                        profile.displayName,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Mesaj',
                      colors: colors,
                      textTheme: textTheme,
                      onTap: () => _handleMessage(
                        context,
                        profile.phone,
                        profile.displayName,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: Text(
                        stats.todayTotal > 0
                            ? '${stats.todayTotal} GÃ¶rev'
                            : 'GÃ¶revler',
                        style: textTheme.labelSmall,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onPressed: onTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCall(BuildContext context, String? phone, String name) {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name iÃ§in telefon numarasÄ± kayÄ±tlÄ± deÄŸil.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name: $phone â€” KopyalandÄ±'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Tamam', onPressed: () {}),
      ),
    );
  }

  void _handleMessage(BuildContext context, String? phone, String name) {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name iÃ§in telefon numarasÄ± kayÄ±tlÄ± deÄŸil.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Numara kopyalandÄ±: $phone'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Tamam', onPressed: () {}),
      ),
    );
  }
}

// â”€â”€ Monthly badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MonthlyBadge extends StatelessWidget {
  const _MonthlyBadge({
    required this.count,
    required this.colors,
    required this.textTheme,
  });

  final int count;
  final AppThemeColors colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: count > 0 ? colors.successContainer : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Bu Ay: $count Ä°ÅŸ',
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: count > 0 ? colors.success : colors.outline,
        ),
      ),
    );
  }
}

// â”€â”€ Action button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.textTheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AppThemeColors colors;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colors.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Technician detail sheet (DraggableScrollableSheet) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TechnicianDetailSheet extends StatelessWidget {
  const _TechnicianDetailSheet({required this.stats});

  final TechnicianStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // â”€â”€ Handle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // â”€â”€ Sheet header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: colors.primary.withValues(alpha: 0.12),
                      child: Text(
                        stats.profile.initials,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
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
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            stats.todayTotal == 0
                                ? 'BugÃ¼n gÃ¶rev yok'
                                : '${stats.todayTotal} gÃ¶rev â€” '
                                      '${stats.todayCompleted} tamamlandÄ±',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colors.outline),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              Divider(height: 20, color: colors.outlineVariant),

              // â”€â”€ Task list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Expanded(
                child: stats.todayTasks.isEmpty
                    ? _SheetEmptyView(name: stats.profile.displayName)
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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

// â”€â”€ Timeline task item â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
          // Time column with connecting line
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
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
                      fontWeight: FontWeight.w800,
                      color: task.isCompleted ? colors.success : colors.primary,
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

          // Task card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onNavigate,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Priority stripe
                          Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: _priorityColor(context, task.priority),
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(12),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Building name
                                  Text(
                                    task.buildingName,
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Address
                                  if (task.address != null &&
                                      task.address!.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color: colors.outline,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            task.address!,
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colors.outline,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  // Notes
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
                                  // Badges row
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _SmallBadge.status(
                                        context,
                                        task.status,
                                        textTheme,
                                      ),
                                      _SmallBadge.priority(
                                        context,
                                        task.priority,
                                        textTheme,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Navigate arrow
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: colors.outline.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
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

  static Color _priorityColor(BuildContext context, String p) {
    final colors = AppThemeColors.of(context);
    switch (p) {
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

// â”€â”€ Small badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.label,
    required this.bg,
    required this.fg,
    required this.textTheme,
  });

  final String label;
  final Color bg;
  final Color fg;
  final TextTheme textTheme;

  factory _SmallBadge.status(
    BuildContext context,
    ScheduleStatus s,
    TextTheme textTheme,
  ) {
    final colors = AppThemeColors.of(context);
    final (lbl, bg, fg) = switch (s) {
      ScheduleStatus.completed => (
        'TAMAMLANDI',
        colors.successContainer,
        colors.success,
      ),
      ScheduleStatus.inProgress => (
        'DEVAM',
        colors.warningContainer,
        colors.warning,
      ),
      ScheduleStatus.cancelled => (
        'İPTAL',
        colors.surfaceContainerHigh,
        colors.onSurfaceVariant,
      ),
      _ => ('BEKLİYOR', colors.surfaceContainer, colors.onSurface),
    };
    return _SmallBadge(label: lbl, bg: bg, fg: fg, textTheme: textTheme);
  }

  factory _SmallBadge.priority(
    BuildContext context,
    String p,
    TextTheme textTheme,
  ) {
    final colors = AppThemeColors.of(context);
    final (lbl, bg, fg) = switch (p) {
      'emergency' => ('ACÄ°L', colors.errorContainer, colors.error),
      'high' => ('YÃœKSEK', colors.warningContainer, colors.warning),
      'low' => (
        'DÃœÅÃœK',
        colors.surfaceContainerHigh,
        colors.onSurfaceVariant,
      ),
      _ => ('NORMAL', colors.surfaceContainer, colors.onSurface),
    };
    return _SmallBadge(label: lbl, bg: bg, fg: fg, textTheme: textTheme);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// â”€â”€ Empty / error states â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.engineering_outlined,
              size: 40,
              color: colors.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'HenÃ¼z teknisyen kaydÄ± yok',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'KullanÄ±cÄ± yÃ¶netiminden teknisyen rolÃ¼ atayÄ±n.',
            style: textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
              'Veriler yÃ¼klenemedi',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              style: textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
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
              size: 36,
              color: colors.outline,
            ),
            const SizedBox(height: 12),
            Text(
              '$name iÃ§in bugÃ¼n\nplanlanmÄ±ÅŸ gÃ¶rev yok',
              textAlign: TextAlign.center,
              style: textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

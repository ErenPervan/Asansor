import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/error_state.dart';

import 'admin_conflict_provider.dart';
import 'admin_conflict_detail_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────

class AdminConflictManagementView extends ConsumerWidget {
  const AdminConflictManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncConflicts = ref.watch(adminConflictProvider);
    final colors = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: asyncConflicts.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LoadingState(count: 3),
        ),
        error: (e, _) => ErrorState(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(adminConflictProvider),
        ),
        data: (conflicts) => _ConflictBody(conflicts: conflicts),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _ConflictBody extends StatelessWidget {
  const _ConflictBody({required this.conflicts});
  final List<ConflictReport> conflicts;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _ConflictAppBar(conflictCount: conflicts.length),
        if (conflicts.isEmpty)
          const SliverFillRemaining(child: _EmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              20,
              AppSpacing.md,
              100,
            ),
            sliver: SliverList.separated(
              itemCount: conflicts.length,
              separatorBuilder: (context, i) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) =>
                  _ConflictCard(report: conflicts[index]),
            ),
          ),
      ],
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────

class _ConflictAppBar extends StatelessWidget {
  const _ConflictAppBar({required this.conflictCount});
  final int conflictCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      elevation: 0,
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primary, colors.navy],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Veri Çakışmaları',
                style: textTheme.headlineSmall?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.0,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: conflictCount > 0
                          ? colors.warningLight
                          : colors.successLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    conflictCount > 0
                        ? '$conflictCount Bekleyen Çakışma'
                        : 'Tüm veriler senkronize',
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.onPrimary.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        title: Text(
          'Veri Çakışmaları',
          style: textTheme.titleLarge?.copyWith(
            color: colors.onPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: AppSpacing.md),
      ),
    );
  }
}

// ── Conflict Card ─────────────────────────────────────────────────────────────

class _ConflictCard extends ConsumerWidget {
  const _ConflictCard({required this.report});
  final ConflictReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elevatorName = report.buildingName ?? report.elevatorId;
    final techName = report.technicianName ?? 'Bilinmiyor';
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AdminConflictDetailDialog(report: report),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: colors.onSurface.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: colors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    elevatorName,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        techName,
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _formatDate(report.createdAt.toIso8601String()),
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.successContainer,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.success.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: colors.success,
                size: 44,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Çakışma yok',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
                letterSpacing: 0.0,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tüm veriler senkronize —\nsistem tamamen uyumlu.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
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

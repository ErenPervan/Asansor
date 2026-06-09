import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/conflicts/admin_conflict_detail_dialog.dart';
import 'package:asansor/features/admin/conflicts/admin_conflict_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminConflictManagementView extends ConsumerWidget {
  const AdminConflictManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final conflicts = ref.watch(adminConflictProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Veri Çakışmaları',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(adminConflictProvider),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: () async {
          ref.invalidate(adminConflictProvider);
          await ref.read(adminConflictProvider.future);
        },
        child: conflicts.when(
          loading: () => const LoadingState(count: 3, height: 96),
          error: (error, _) => ErrorState(
            message: error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(adminConflictProvider),
          ),
          data: (items) => _ConflictContent(conflicts: items),
        ),
      ),
    );
  }
}

class _ConflictContent extends StatelessWidget {
  const _ConflictContent({required this.conflicts});

  final List<ConflictReport> conflicts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        110,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConflictHero(conflictCount: conflicts.length),
                const SizedBox(height: AppSpacing.lg),
                if (conflicts.isEmpty)
                  const _EmptyState()
                else ...[
                  _StatusPanel(conflictCount: conflicts.length),
                  const SizedBox(height: AppSpacing.lg),
                  for (var i = 0; i < conflicts.length; i++) ...[
                    _ConflictCard(report: conflicts[i]),
                    if (i < conflicts.length - 1)
                      const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConflictHero extends StatelessWidget {
  const _ConflictHero({required this.conflictCount});

  final int conflictCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final hasConflicts = conflictCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.16),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -54,
            child: Icon(
              Icons.sync_problem_rounded,
              size: 176,
              color: colors.onPrimary.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      hasConflicts
                          ? Icons.warning_amber_rounded
                          : Icons.verified_rounded,
                      color: colors.onPrimary,
                    ),
                  ),
                  const Spacer(),
                  _HeroBadge(conflictCount: conflictCount),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Veri Çakışmaları',
                style: textTheme.headlineMedium?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                hasConflicts
                    ? 'Çevrimdışı senkronizasyon sırasında tespit edilen uyuşmazlıkları inceleyin.'
                    : 'Tüm yerel ve uzak kayıtlar senkronize durumda.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.conflictCount});

  final int conflictCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final hasConflicts = conflictCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hasConflicts ? AppColors.accentGold : colors.successLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            hasConflicts ? '$conflictCount Bekleyen' : 'Senkronize',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.conflictCount});

  final int conflictCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.pause_circle_rounded, color: colors.error),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Senkronizasyon duraklatıldı',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$conflictCount kayıt manuel karar bekliyor.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Text(
            '$conflictCount',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _ConflictCard extends ConsumerWidget {
  const _ConflictCard({required this.report});

  final ConflictReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final elevatorName = report.buildingName ?? report.elevatorId;
    final techName = report.technicianName ?? 'Bilinmeyen Teknisyen';
    final fieldCount = _visibleKeyCount(report);

    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AdminConflictDetailDialog(report: report),
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.06),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.elevator_rounded, color: colors.error),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            elevatorName,
                            style: textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _SeverityBadge(count: fieldCount),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _MetaItem(
                          icon: Icons.person_rounded,
                          label: techName,
                        ),
                        _MetaItem(
                          icon: Icons.schedule_rounded,
                          label: _formatDate(report.createdAt),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.compare_arrows_rounded,
                            color: colors.primaryDark,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '$fieldCount çakışan alan incelenmeli',
                              style: textTheme.labelLarge?.copyWith(
                                color: colors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colors.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final critical = count >= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: critical ? colors.errorContainer : AppColors.accentGold.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        critical ? 'Kritik' : 'Orta',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: critical ? colors.onErrorContainer : colors.warning,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colors.successContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: colors.success,
              size: 46,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Tüm veriler senkronize',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bekleyen herhangi bir veri çakışması bulunmuyor.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

int _visibleKeyCount(ConflictReport report) {
  const excluded = {'id', 'base_version', 'updated_at', 'version'};
  final keys = <String>{
    ...report.localPayload.keys,
    ...report.remotePayload.keys,
  }.where((key) => !excluded.contains(key)).toSet();
  return keys.length;
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

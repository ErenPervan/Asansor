import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:asansor/features/fault/providers/fault_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:asansor/l10n/app_localizations.dart';

const _panelLine = Color(0xFFE1E8F0);

class FaultListView extends ConsumerStatefulWidget {
  const FaultListView({super.key});

  @override
  ConsumerState<FaultListView> createState() => _FaultListViewState();
}

class _FaultListViewState extends ConsumerState<FaultListView> {
  int _filterIndex = 0;

  Future<void> _refresh() async {
    ref.invalidate(allFaultsProvider);
    ref.invalidate(elevatorsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final faultsAsync = ref.watch(allFaultsProvider);
    final elevatorsAsync = ref.watch(elevatorsProvider);

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
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: faultsAsync.when(
        loading: () => const LoadingState(),
        error: (e, st) => _ErrorBody(error: e, onRetry: _refresh),
        data: (allFaults) {
          final elevators =
              elevatorsAsync.valueOrNull ?? const <ElevatorModel>[];
          final elevatorMap = {
            for (final elevator in elevators) elevator.id: elevator,
          };
          final filtered = _filtered(allFaults);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PageHeader(
                          total: allFaults.length,
                          open: allFaults.where((f) => !f.isResolved).length,
                          resolved: allFaults.where((f) => f.isResolved).length,
                          urgent: allFaults.where(_isUrgentOpen).length,
                          onRefresh: _refresh,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _FilterBar(
                          selectedIndex: _filterIndex,
                          onSelected: (value) =>
                              setState(() => _filterIndex = value),
                          allCount: allFaults.length,
                          openCount: allFaults
                              .where((f) => !f.isResolved)
                              .length,
                          resolvedCount: allFaults
                              .where((f) => f.isResolved)
                              .length,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (filtered.isEmpty)
                          _EmptyBody(filterIndex: _filterIndex)
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 820
                                  ? 2
                                  : 1;
                              final cardWidth =
                                  (constraints.maxWidth -
                                      ((columns - 1) * AppSpacing.md)) /
                                  columns;

                              return Wrap(
                                spacing: AppSpacing.md,
                                runSpacing: AppSpacing.md,
                                children: [
                                  for (final fault in filtered)
                                    SizedBox(
                                      width: cardWidth,
                                      child: _FaultCard(
                                        fault: fault,
                                        elevator: elevatorMap[fault.elevatorId],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<FaultReportModel> _filtered(List<FaultReportModel> faults) {
    final result = faults.where((fault) {
      if (_filterIndex == 1) return !fault.isResolved;
      if (_filterIndex == 2) return fault.isResolved;
      return true;
    }).toList();
    result.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    return result;
  }

  static bool _isUrgentOpen(FaultReportModel fault) {
    if (fault.isResolved) return false;
    return fault.priority == 'emergency' || fault.priority == 'high';
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.total,
    required this.open,
    required this.resolved,
    required this.urgent,
    required this.onRefresh,
  });

  final int total;
  final int open;
  final int resolved;
  final int urgent;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
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
                        'Arızalar',
                        style: textTheme.headlineSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Kayıtlı asansör arızalarını, öncelikleri ve çözüm durumlarını takip edin.',
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
                  label: Text(AppLocalizations.of(context)!.faultListRefresh),
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
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _MetricCard(
              label: 'Toplam Kayıt',
              value: '$total',
              icon: Icons.error_outline_rounded,
              color: colors.primary,
            ),
            _MetricCard(
              label: 'Açık',
              value: '$open',
              icon: Icons.warning_rounded,
              color: colors.error,
            ),
            _MetricCard(
              label: 'Acil',
              value: '$urgent',
              icon: Icons.priority_high_rounded,
              color: AppColors.accentGold,
            ),
            _MetricCard(
              label: 'Çözüldü',
              value: '$resolved',
              icon: Icons.check_circle_rounded,
              color: colors.success,
            ),
          ],
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
      width: 188,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surface,
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
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: textTheme.titleLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.allCount,
    required this.openCount,
    required this.resolvedCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int allCount;
  final int openCount;
  final int resolvedCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterPill(
            label: 'Tümü',
            count: allCount,
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterPill(
            label: 'Açık',
            count: openCount,
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterPill(
            label: 'Çözüldü',
            count: resolvedCount,
            selected: selectedIndex == 2,
            onTap: () => onSelected(2),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          '$label  $count',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _FaultCard extends StatelessWidget {
  const _FaultCard({required this.fault, required this.elevator});

  final FaultReportModel fault;
  final ElevatorModel? elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final visual = _visual(context, fault);
    final reportedAt = fault.reportedAt.toLocal();
    final time = DateFormat('HH:mm', 'tr_TR').format(reportedAt);
    final date = DateFormat('d MMM y', 'tr_TR').format(reportedAt);
    final ago = _relativeTime(reportedAt);
    final title = elevator?.buildingName ?? 'Bilinmeyen Asansör';
    final address = elevator?.address;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/fault/${fault.id}'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 236),
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
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: visual.color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (address != null &&
                                      address.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 15,
                                          color: colors.outline,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            address,
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _FaultStatusBadge(visual: visual),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.symmetric(
                              horizontal: BorderSide(
                                color: colors.outlineVariant.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                            ),
                          ),
                          child: Text(
                            fault.description.isEmpty
                                ? 'Açıklama girilmemiş.'
                                : fault.description,
                            style: textTheme.bodyMedium?.copyWith(
                              color: fault.isResolved
                                  ? colors.onSurfaceVariant
                                  : colors.onSurface,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.sm,
                          children: [
                            _MetaItem(
                              icon: Icons.schedule_rounded,
                              label: time,
                            ),
                            _MetaItem(
                              icon: Icons.calendar_today_rounded,
                              label: date,
                            ),
                            _MetaItem(icon: Icons.history_rounded, label: ago),
                            if (fault.faultType != null &&
                                fault.faultType!.isNotEmpty)
                              _MetaItem(
                                icon: Icons.category_rounded,
                                label: fault.faultType!,
                              ),
                            if (fault.isOfflineQueued)
                              _MetaItem(
                                icon: Icons.cloud_off_rounded,
                                label: 'Senkron bekliyor',
                                color: colors.warning,
                              ),
                          ],
                        ),
                        const Spacer(),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fault.isResolved
                                    ? 'Çözüm kaydı görüntülenebilir'
                                    : 'Müdahale süreci açık',
                                style: textTheme.labelMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              fault.isResolved ? 'Rapor' : 'Detaylar',
                              style: textTheme.labelLarge?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              fault.isResolved
                                  ? Icons.description_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                              color: colors.primary,
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
      ),
    );
  }

  static _FaultVisual _visual(BuildContext context, FaultReportModel fault) {
    final colors = AppThemeColors.of(context);
    if (fault.isResolved) {
      return _FaultVisual(
        label: 'Çözüldü',
        color: colors.success,
        background: colors.successContainer,
        icon: Icons.check_circle_rounded,
      );
    }
    if (fault.priority == 'emergency' || fault.priority == 'high') {
      return _FaultVisual(
        label: 'Acil Arıza',
        color: colors.error,
        background: colors.errorContainer,
        icon: Icons.warning_rounded,
      );
    }
    return _FaultVisual(
      label: 'Açık',
      color: colors.primary,
      background: colors.primaryContainer,
      icon: Icons.error_outline_rounded,
    );
  }
}

class _FaultVisual {
  const _FaultVisual({
    required this.label,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData icon;
}

class _FaultStatusBadge extends StatelessWidget {
  const _FaultStatusBadge({required this.visual});

  final _FaultVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: visual.background.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: visual.color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, color: visual.color, size: 15),
          const SizedBox(width: 5),
          Text(
            visual.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: visual.color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final itemColor = color ?? colors.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: itemColor, size: 16),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: itemColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.filterIndex});

  final int filterIndex;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final message = switch (filterIndex) {
      1 => 'Açık arıza bulunamadı.',
      2 => 'Çözülmüş arıza bulunamadı.',
      _ => 'Henüz arıza kaydı bulunmuyor.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelLine),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: colors.outline,
            size: 44,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
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
              'Arıza kayıtları yüklenemedi',
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
              label: Text(AppLocalizations.of(context)!.generalRetry),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Şimdi';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} saat önce';
  if (diff.inDays == 1) return 'Dün';
  if (diff.inDays < 30) return '${diff.inDays} gün önce';
  return DateFormat('d MMM', 'tr_TR').format(date);
}

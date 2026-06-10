import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/animations/fade_in_slide.dart';
import 'package:asansor/core/widgets/app_async_view.dart';
import 'package:asansor/core/widgets/empty_state.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

typedef _StatusStyle = ({
  Color bg,
  Color fg,
  Color border,
  String label,
  IconData icon,
});

_StatusStyle _statusStyle(ElevatorStatus status, AppThemeColors colors) {
  switch (status) {
    case ElevatorStatus.active:
      return (
        bg: colors.primaryFixed.withValues(alpha: 0.62),
        fg: colors.primaryDark,
        border: colors.primary.withValues(alpha: 0.14),
        label: 'Aktif',
        icon: Icons.check_circle_outline_rounded,
      );
    case ElevatorStatus.faulty:
      return (
        bg: colors.errorContainer.withValues(alpha: 0.62),
        fg: colors.onErrorContainer,
        border: colors.error.withValues(alpha: 0.22),
        label: 'Arızalı',
        icon: Icons.warning_amber_rounded,
      );
    case ElevatorStatus.underMaintenance:
      return (
        bg: colors.warningContainer.withValues(alpha: 0.72),
        fg: colors.warning,
        border: colors.warning.withValues(alpha: 0.22),
        label: 'Bakımda',
        icon: Icons.build_circle_outlined,
      );
    case ElevatorStatus.inactive:
      return (
        bg: colors.surfaceContainer,
        fg: colors.outline,
        border: colors.outlineVariant,
        label: 'Pasif',
        icon: Icons.pause_circle_outline_rounded,
      );
  }
}

class ElevatorListView extends ConsumerStatefulWidget {
  const ElevatorListView({super.key});

  @override
  ConsumerState<ElevatorListView> createState() => _ElevatorListViewState();
}

class _ElevatorListViewState extends ConsumerState<ElevatorListView> {
  final _searchController = TextEditingController();
  String _query = '';
  ElevatorStatus? _selectedStatus;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ElevatorModel> _applyFilter(List<ElevatorModel> all) {
    var filtered = all;
    final selectedStatus = _selectedStatus;
    if (selectedStatus != null) {
      filtered = filtered.where((e) => e.status == selectedStatus).toList();
    }

    if (_query.trim().isEmpty) return filtered;

    final q = _query.trim().toLowerCase();
    return filtered.where((e) {
      return e.buildingName.toLowerCase().contains(q) ||
          e.id.toLowerCase().contains(q) ||
          (e.address?.toLowerCase().contains(q) ?? false) ||
          (e.model?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Map<ElevatorStatus, int> _counts(List<ElevatorModel> elevators) {
    return {
      for (final status in ElevatorStatus.values)
        status: elevators.where((e) => e.status == status).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final elevatorsAsync = ref.watch(elevatorsProvider);
    final colors = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.apartment_rounded, color: colors.primaryDark),
          tooltip: 'Operasyon',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'ElevatePro',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              color: colors.primaryDark,
            ),
            tooltip: 'Bildirimler',
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.primaryDark),
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(elevatorsProvider),
          ),
        ],
      ),
      body: AppAsyncView<List<ElevatorModel>>(
        value: elevatorsAsync,
        onRetry: () => ref.invalidate(elevatorsProvider),
        emptyMessage:
            'Asansör Bulunamadı\n\nSisteme henüz asansör eklenmemiş.\nLütfen yöneticinizle iletişime geçin.',
        emptyIcon: Icons.elevator_outlined,
        data: (all) {
          final counts = _counts(all);
          final items = _applyFilter(all);

          return RefreshIndicator(
            color: colors.primary,
            onRefresh: () async {
              final _ = await ref.refresh(elevatorsProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _FleetHeader(
                    total: all.length,
                    query: _query,
                    controller: _searchController,
                    onQueryChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StatusFilterBar(
                    selectedStatus: _selectedStatus,
                    counts: counts,
                    onSelected: (status) =>
                        setState(() => _selectedStatus = status),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.search_off_outlined,
                      message:
                          'Sonuç Yok\n\n"$_query" ile eşleşen asansör bulunamadı.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.crossAxisExtent >= 720;
                        if (isWide) {
                          return SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: AppSpacing.md,
                                  mainAxisSpacing: AppSpacing.md,
                                  mainAxisExtent: 174,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final elevator = items[index];
                              return FadeInSlide(
                                index: index,
                                child: _ElevatorFleetCard(
                                  elevator: elevator,
                                  onTap: () =>
                                      context.push('/elevator/${elevator.id}'),
                                ),
                              );
                            }, childCount: items.length),
                          );
                        }

                        return SliverList.separated(
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final elevator = items[index];
                            return FadeInSlide(
                              index: index,
                              child: _ElevatorFleetCard(
                                elevator: elevator,
                                onTap: () =>
                                    context.push('/elevator/${elevator.id}'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FleetHeader extends StatelessWidget {
  const _FleetHeader({
    required this.total,
    required this.query,
    required this.controller,
    required this.onQueryChanged,
    required this.onClear,
  });

  final int total;
  final String query;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filo Yönetimi',
                      style: textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tesis & Asansörler',
                      style: textTheme.headlineSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryFixed.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$total',
                      style: textTheme.headlineMedium?.copyWith(
                        color: colors.primaryDark,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toplam Ünite',
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Bina, adres veya ünite no ara...',
              prefixIcon: Icon(Icons.search_rounded, color: colors.outline),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: colors.outline),
                      tooltip: 'Aramayı temizle',
                      onPressed: onClear,
                    )
                  : null,
              filled: true,
              fillColor: colors.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colors.primary.withValues(alpha: 0.42),
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.selectedStatus,
    required this.counts,
    required this.onSelected,
  });

  final ElevatorStatus? selectedStatus;
  final Map<ElevatorStatus, int> counts;
  final ValueChanged<ElevatorStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final filters = <({String label, ElevatorStatus? status, int count})>[
      (
        label: 'Tümü',
        status: null,
        count: counts.values.fold(0, (a, b) => a + b),
      ),
      (
        label: 'Aktif',
        status: ElevatorStatus.active,
        count: counts[ElevatorStatus.active] ?? 0,
      ),
      (
        label: 'Arızalı',
        status: ElevatorStatus.faulty,
        count: counts[ElevatorStatus.faulty] ?? 0,
      ),
      (
        label: 'Bakımda',
        status: ElevatorStatus.underMaintenance,
        count: counts[ElevatorStatus.underMaintenance] ?? 0,
      ),
      (
        label: 'Pasif',
        status: ElevatorStatus.inactive,
        count: counts[ElevatorStatus.inactive] ?? 0,
      ),
    ];

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          return _StatusFilterChip(
            label: filter.label,
            count: filter.count,
            status: filter.status,
            isSelected: selectedStatus == filter.status,
            onTap: () => onSelected(filter.status),
          );
        },
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.count,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final ElevatorStatus? status;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final style = status == null ? null : _statusStyle(status!, colors);
    final selectedBg = colors.primaryDark;
    final idleBg = colors.surfaceContainerHigh;
    final dotColor = style?.fg ?? colors.primaryDark;

    return Material(
      color: isSelected ? selectedBg : idleBg,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              if (status != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isSelected ? colors.onPrimary : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '$label ($count)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? colors.onPrimary
                      : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElevatorFleetCard extends StatelessWidget {
  const _ElevatorFleetCard({required this.elevator, required this.onTap});

  final ElevatorModel elevator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final style = _statusStyle(elevator.status, colors);
    final accent = elevator.status == ElevatorStatus.active
        ? colors.primaryDark
        : style.fg;

    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: elevator.status == ElevatorStatus.active
                  ? colors.outlineVariant.withValues(alpha: 0.5)
                  : style.border,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.06),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (elevator.status == ElevatorStatus.faulty)
                Positioned(
                  left: -AppSpacing.lg,
                  top: -AppSpacing.lg,
                  bottom: -AppSpacing.lg,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: colors.error,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              Column(
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
                              elevator.buildingName,
                              style: textTheme.titleMedium?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 17,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    elevator.address?.isNotEmpty == true
                                        ? elevator.address!
                                        : 'Adres bilgisi yok',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _StatusPill(style: style),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Divider(
                    color: colors.outlineVariant.withValues(alpha: 0.36),
                    height: AppSpacing.lg,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _FleetMeta(
                          icon: Icons.calendar_today_outlined,
                          label: _maintenanceLabel(elevator),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: accent,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _maintenanceLabel(ElevatorModel elevator) {
    if (elevator.nextInspectionDate != null) {
      return 'Sonraki kontrol: ${_formatDate(elevator.nextInspectionDate!)}';
    }
    if (elevator.lastInspectionDate != null) {
      return 'Son bakım: ${_formatDate(elevator.lastInspectionDate!)}';
    }
    if (elevator.maintenanceDay != null) {
      return 'Bakım günü: Her ay ${elevator.maintenanceDay}. gün';
    }
    if (elevator.model?.isNotEmpty == true) {
      return elevator.model!;
    }
    return 'Bakım bilgisi bekleniyor';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.style});

  final _StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 15, color: style.fg),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: style.fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FleetMeta extends StatelessWidget {
  const _FleetMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      children: [
        Icon(icon, color: colors.outline, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.outline,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

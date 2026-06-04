import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/animations/fade_in_slide.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../models/elevator_model.dart';
import '../providers/elevator_providers.dart';

// ── Status helpers ────────────────────────────────────────────────────────────

typedef _StatusStyle = ({
  Color bg,
  Color fg,
  Color iconBg,
  Color iconFg,
  String label,
  IconData icon,
});

_StatusStyle _statusStyle(ElevatorStatus status, AppThemeColors colors) {
  switch (status) {
    case ElevatorStatus.active:
      return (
        bg: colors.successContainer,
        fg: colors.success,
        iconBg: colors.successContainer,
        iconFg: colors.success,
        label: 'Aktif',
        icon: Icons.check_circle_outline,
      );
    case ElevatorStatus.faulty:
      return (
        bg: colors.errorContainer,
        fg: colors.error,
        iconBg: colors.errorContainer,
        iconFg: colors.error,
        label: 'Arızalı',
        icon: Icons.error_outline,
      );
    case ElevatorStatus.underMaintenance:
      return (
        bg: colors.warningContainer,
        fg: colors.warning,
        iconBg: colors.warningContainer,
        iconFg: colors.warning,
        label: 'Bakımda',
        icon: Icons.build_outlined,
      );
    case ElevatorStatus.inactive:
      return (
        bg: colors.surfaceContainer,
        fg: colors.outline,
        iconBg: colors.surfaceContainer,
        iconFg: colors.outline,
        label: 'Pasif',
        icon: Icons.pause_circle_outline,
      );
  }
}

// ── ElevatorListView ──────────────────────────────────────────────────────────

class ElevatorListView extends ConsumerStatefulWidget {
  const ElevatorListView({super.key});

  @override
  ConsumerState<ElevatorListView> createState() => _ElevatorListViewState();
}

class _ElevatorListViewState extends ConsumerState<ElevatorListView> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedStatus = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ElevatorModel> _applyFilter(List<ElevatorModel> all) {
    var filtered = all;
    if (_selectedStatus != 'all') {
      filtered = filtered
          .where((e) => e.status.name == _selectedStatus)
          .toList();
    }
    if (_query.trim().isEmpty) return filtered;

    final q = _query.trim().toLowerCase();
    return filtered.where((e) {
      return e.buildingName.toLowerCase().contains(q) ||
          (e.address?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final elevatorsAsync = ref.watch(elevatorsProvider);

    return Scaffold(
      backgroundColor: AppThemeColors.of(context).background,
      // ── App Bar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Asansörlerim'),
        actions: [
          // Show total count badge while data is available.
          elevatorsAsync.maybeWhen(
            data: (all) => Center(
              child: Container(
                margin: const EdgeInsets.only(right: AppSpacing.md),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppThemeColors.of(
                    context,
                  ).primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${all.length} Asansör',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppThemeColors.of(context).primary,
                  ),
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(elevatorsProvider),
          ),
        ],
        // ── Search bar lives inside the AppBar's bottom slot ─────────────
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              12,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppThemeColors.of(context).onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Bina adı veya adres ile ara…',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppThemeColors.of(
                    context,
                  ).outline.withValues(alpha: 0.8),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppThemeColors.of(context).outline,
                  size: 20,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: AppThemeColors.of(context).outline,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppThemeColors.of(context).surfaceContainer,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppThemeColors.of(
                      context,
                    ).primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: Column(
        children: [
          // Status Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                _StatusFilterChip(
                  label: 'Tümü',
                  isSelected: _selectedStatus == 'all',
                  onSelected: () => setState(() => _selectedStatus = 'all'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusFilterChip(
                  label: 'Aktif',
                  isSelected: _selectedStatus == 'active',
                  onSelected: () => setState(() => _selectedStatus = 'active'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusFilterChip(
                  label: 'Arızalı',
                  isSelected: _selectedStatus == 'faulty',
                  onSelected: () => setState(() => _selectedStatus = 'faulty'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusFilterChip(
                  label: 'Bakımda',
                  isSelected: _selectedStatus == 'under_maintenance',
                  onSelected: () =>
                      setState(() => _selectedStatus = 'under_maintenance'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusFilterChip(
                  label: 'Pasif',
                  isSelected: _selectedStatus == 'inactive',
                  onSelected: () =>
                      setState(() => _selectedStatus = 'inactive'),
                ),
              ],
            ),
          ),

          Expanded(
            child: AppAsyncView<List<ElevatorModel>>(
              value: elevatorsAsync,
              onRetry: () => ref.invalidate(elevatorsProvider),
              emptyMessage:
                  'Asansör Bulunamadı\n\nSisteme henüz asansör eklenmemiş.\nLütfen yöneticinizle iletişime geçin.',
              emptyIcon: Icons.elevator_outlined,
              data: (all) {
                final items = _applyFilter(all);

                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off_outlined,
                    message:
                        'Sonuç Yok\n\n"$_query" ile eşleşen asansör bulunamadı.',
                  );
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: RefreshIndicator(
                    key: ValueKey('list-$_selectedStatus-$_query'),
                    color: AppThemeColors.of(context).primary,
                    onRefresh: () async => ref.invalidate(elevatorsProvider),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 600) {
                          return GridView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 8,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisExtent: 104,
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final elevator = items[index];
                              return FadeInSlide(
                                index: index,
                                child: _ElevatorCard(
                                  elevator: elevator,
                                  onTap: () =>
                                      context.push('/elevator/${elevator.id}'),
                                ),
                              );
                            },
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 8,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final elevator = items[index];
                            return FadeInSlide(
                              index: index,
                              child: _ElevatorCard(
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Elevator Card ─────────────────────────────────────────────────────────────

class _ElevatorCard extends StatelessWidget {
  const _ElevatorCard({required this.elevator, required this.onTap});

  final ElevatorModel elevator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final style = _statusStyle(elevator.status, colors);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          // ── Status icon ──────────────────────────────────────────
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: style.iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(style.icon, color: style.iconFg, size: 26),
          ),
          const SizedBox(width: 14),

          // ── Name + address ───────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  elevator.buildingName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (elevator.address != null &&
                    elevator.address!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          elevator.address!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.3,
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

          // ── Status badge + chevron ───────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppStatusChip(
                label: style.label,
                color: style.fg,
                backgroundColor: style.bg,
                size: AppStatusChipSize.small,
              ),
              const SizedBox(height: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: colors.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: colors.primary.withValues(alpha: 0.15),
      labelStyle: textTheme.labelMedium?.copyWith(
        color: isSelected ? colors.primary : colors.outline,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? colors.primary : colors.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }
}

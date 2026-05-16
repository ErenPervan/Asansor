import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/offline_banner.dart';
import '../models/elevator_model.dart';
import '../providers/elevator_providers.dart';
import '../../../../core/theme/app_colors.dart';

// ── Status helpers ────────────────────────────────────────────────────────────

typedef _StatusStyle = ({
  Color bg,
  Color fg,
  Color iconBg,
  Color iconFg,
  String label,
  IconData icon,
});

_StatusStyle _statusStyle(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return (
        bg: AppColors.successContainer,
        fg: AppColors.success,
        iconBg: AppColors.successContainer.withValues(alpha: 0.1),
        iconFg: AppColors.success,
        label: 'Aktif',
        icon: Icons.check_circle_outline,
      );
    case 'faulty':
      return (
        bg: AppColors.errorContainer,
        fg: AppColors.error,
        iconBg: AppColors.errorContainer.withValues(alpha: 0.1),
        iconFg: AppColors.error,
        label: 'Arızalı',
        icon: Icons.error_outline,
      );
    case 'under_maintenance':
      return (
        bg: AppColors.warningContainer,
        fg: AppColors.warning,
        iconBg: AppColors.warningContainer.withValues(alpha: 0.1),
        iconFg: AppColors.warning,
        label: 'Bakımda',
        icon: Icons.build_outlined,
      );
    case 'inactive':
      return (
        bg: AppColors.surfaceLight,
        fg: AppColors.textSecondary,
        iconBg: AppColors.surfaceLight,
        iconFg: AppColors.textSecondary,
        label: 'Pasif',
        icon: Icons.pause_circle_outline,
      );
    default:
      return (
        bg: AppColors.surfaceLight,
        fg: AppColors.textSecondary,
        iconBg: AppColors.surfaceLight,
        iconFg: AppColors.textSecondary,
        label: 'Bilinmiyor',
        icon: Icons.help_outline,
      );
  }
}

// ── ElevatorListView ──────────────────────────────────────────────────────────

class ElevatorListView extends ConsumerStatefulWidget {
  const ElevatorListView({super.key});

  @override
  ConsumerState<ElevatorListView> createState() => _ElevatorListViewState();
}

// Null = "Tümü", diğer değerler: 'active', 'faulty', 'under_maintenance', 'inactive'
typedef _FilterChip = ({String? status, String label, IconData icon});

const _filterChips = <_FilterChip>[
  (status: null, label: 'Tümü', icon: Icons.apps_rounded),
  (status: 'active', label: 'Aktif', icon: Icons.check_circle_outline),
  (status: 'faulty', label: 'Arızalı', icon: Icons.error_outline),
  (status: 'under_maintenance', label: 'Bakımda', icon: Icons.build_outlined),
  (status: 'inactive', label: 'Pasif', icon: Icons.pause_circle_outline),
];

class _ElevatorListViewState extends ConsumerState<ElevatorListView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';

  /// Null = tüm durumlar
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Filtre aktifken sonsuz scroll'u devre dışı bırak (sunucu sayfalama yerine
    // istemci tarafı filtreleme yapılıyor, daha fazla yüklemeye gerek yok).
    if (_query.isNotEmpty || _statusFilter != null) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(elevatorListProvider.notifier).loadMore();
    }
  }

  List<ElevatorModel> _applyFilter(List<ElevatorModel> all) {
    var result = all;
    // 1. Metin filtresi
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      result = result.where((e) {
        return e.buildingName.toLowerCase().contains(q) ||
            (e.address?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    // 2. Durum filtresi
    if (_statusFilter != null) {
      result = result
          .where((e) => e.status.toLowerCase() == _statusFilter)
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elevatorsAsync = ref.watch(elevatorListProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Asansörlerim',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          elevatorsAsync.maybeWhen(
            data: (paginated) => Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${paginated.items.length}${paginated.hasMore ? "+" : ""} Asansör',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
        bottom: PreferredSize(
          // Arama alanı 56 px + chip satırı 52 px + dikey boşluk = 120 px
          preferredSize: const Size.fromHeight(120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Bina adı veya adres ile ara…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              // ── Durum filtresi chip satırı ──────────────────────────────
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: _filterChips.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final chip = _filterChips[i];
                    final isSelected = _statusFilter == chip.status;
                    final primary = theme.colorScheme.primary;
                    return GestureDetector(
                      onTap: () => setState(() => _statusFilter = chip.status),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? primary : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? primary
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              chip.icon,
                              size: 14,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              chip.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: elevatorsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorBody(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () =>
                    ref.read(elevatorListProvider.notifier).refresh(),
              ),
              data: (paginated) {
                final items = _applyFilter(paginated.items);

                if (paginated.items.isEmpty) {
                  return const _EmptyBody(
                    icon: Icons.elevator_outlined,
                    title: 'Asansör Bulunamadı',
                    subtitle: 'Sisteme henüz asansör eklenmemiş.',
                  );
                }

                // Filtre sonucu boş
                if (items.isEmpty) {
                  final filterLabel = _statusFilter == null
                      ? ''
                      : _filterChips
                            .firstWhere((c) => c.status == _statusFilter)
                            .label;
                  return _EmptyBody(
                    icon: Icons.filter_list_off_rounded,
                    title: 'Sonuç Bulunamadı',
                    subtitle: _statusFilter != null
                        ? '"$filterLabel" durumunda asansör yok.'
                        : 'Arama kriterine uygun asansör bulunamadı.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(elevatorListProvider.notifier).refresh(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    // Filtre aktifken sonsuz scroll göstergesi gizlenir
                    itemCount:
                        items.length +
                        (paginated.hasMore &&
                                _query.isEmpty &&
                                _statusFilter == null
                            ? 1
                            : 0),
                    itemBuilder: (context, i) {
                      if (i == items.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return _ElevatorCard(
                        elevator: items[i],
                        onTap: () => context.push('/elevator/${items[i].id}'),
                      );
                    },
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

class _ElevatorCard extends StatelessWidget {
  const _ElevatorCard({required this.elevator, required this.onTap});

  final ElevatorModel elevator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _statusStyle(elevator.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: style.iconBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(style.icon, color: style.iconFg, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        elevator.buildingName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        elevator.address ?? 'Adres belirtilmemiş',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: style.bg.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: style.bg.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        style.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: style.fg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
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
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
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

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

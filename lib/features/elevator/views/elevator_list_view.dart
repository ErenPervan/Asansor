import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/animations/fade_in_slide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/offline_banner.dart';
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

_StatusStyle _statusStyle(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return (
        bg: AppColors.successContainer,
        fg: AppColors.success,
        iconBg: AppColors.successContainer,
        iconFg: AppColors.success,
        label: 'Aktif',
        icon: Icons.check_circle_outline,
      );
    case 'faulty':
      return (
        bg: AppColors.errorContainer,
        fg: AppColors.error,
        iconBg: AppColors.errorContainer,
        iconFg: AppColors.error,
        label: 'Arızalı',
        icon: Icons.error_outline,
      );
    case 'under_maintenance':
      return (
        bg: AppColors.warningContainer,
        fg: AppColors.warning,
        iconBg: AppColors.warningContainer,
        iconFg: AppColors.warning,
        label: 'Bakımda',
        icon: Icons.build_outlined,
      );
    case 'inactive':
      return (
        bg: AppColors.surfaceContainer,
        fg: AppColors.outline,
        iconBg: AppColors.surfaceContainer,
        iconFg: AppColors.outline,
        label: 'Pasif',
        icon: Icons.pause_circle_outline,
      );
    default:
      return (
        bg: AppColors.surfaceContainer,
        fg: AppColors.outline,
        iconBg: AppColors.surfaceContainer,
        iconFg: AppColors.outline,
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
          .where((e) => e.status.toLowerCase() == _selectedStatus)
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Asansörlerim',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        actions: [
          // Show total count badge while data is available.
          elevatorsAsync.maybeWhen(
            data: (all) => Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${all.length} Asansör',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Bina adı veya adres ile ara…',
                hintStyle: TextStyle(
                  color: AppColors.outline.withValues(alpha: 0.8),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.outline,
                  size: 20,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.outline,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
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
                    color: AppColors.primary.withValues(alpha: 0.4),
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
          // Shows an amber "offline / cached data" strip when there is no
          // internet connection; renders nothing when online.
          const OfflineBanner(),

          // Status Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _StatusFilterChip(
                  label: 'Tümü',
                  isSelected: _selectedStatus == 'all',
                  onSelected: () => setState(() => _selectedStatus = 'all'),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Aktif',
                  isSelected: _selectedStatus == 'active',
                  onSelected: () => setState(() => _selectedStatus = 'active'),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Arızalı',
                  isSelected: _selectedStatus == 'faulty',
                  onSelected: () => setState(() => _selectedStatus = 'faulty'),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Bakımda',
                  isSelected: _selectedStatus == 'under_maintenance',
                  onSelected: () =>
                      setState(() => _selectedStatus = 'under_maintenance'),
                ),
                const SizedBox(width: 8),
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
            child: elevatorsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: LoadingState(count: 6),
              ),
              error: (e, _) => _ErrorBody(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(elevatorsProvider),
              ),
              data: (all) {
                final items = _applyFilter(all);

                if (all.isEmpty) {
                  return const _EmptyBody(
                    icon: Icons.elevator_outlined,
                    title: 'Asansör Bulunamadı',
                    subtitle:
                        'Sisteme henüz asansör eklenmemiş.\nLütfen yöneticinizle iletişime geçin.',
                  );
                }

                if (items.isEmpty) {
                  return _EmptyBody(
                    icon: Icons.search_off_outlined,
                    title: 'Sonuç Yok',
                    subtitle: '"$_query" ile eşleşen asansör bulunamadı.',
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(elevatorsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
                          onTap: () => context.push('/elevator/${elevator.id}'),
                        ),
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

// ── Elevator Card ─────────────────────────────────────────────────────────────

class _ElevatorCard extends StatelessWidget {
  const _ElevatorCard({required this.elevator, required this.onTap});

  final ElevatorModel elevator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(elevator.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
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
                      Material(
                        color: Colors.transparent,
                        child: Text(
                          elevator.buildingName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (elevator.address != null &&
                          elevator.address!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                elevator.address!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: style.bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        style.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: style.fg,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: AppColors.outline,
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

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty body ────────────────────────────────────────────────────────────────

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.outline),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
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
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.outline,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }
}

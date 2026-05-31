import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/fault_providers.dart';
import '../models/fault_report_model.dart';
import '../../elevator/providers/elevator_providers.dart';

class FaultListView extends ConsumerStatefulWidget {
  const FaultListView({super.key});

  @override
  ConsumerState<FaultListView> createState() => _FaultListViewState();
}

class _FaultListViewState extends ConsumerState<FaultListView> {
  int _filterIndex = 0; // 0: All, 1: Active, 2: Resolved

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final faultsAsync = ref.watch(allFaultsProvider);
    final elevatorsAsync = ref.watch(elevatorsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        title: const Text(
          'Arızalar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tümü',
                  isSelected: _filterIndex == 0,
                  onSelected: () => setState(() => _filterIndex = 0),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Açık',
                  isSelected: _filterIndex == 1,
                  onSelected: () => setState(() => _filterIndex = 1),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Çözüldü',
                  isSelected: _filterIndex == 2,
                  onSelected: () => setState(() => _filterIndex = 2),
                ),
              ],
            ),
          ),
        ),
      ),
      body: faultsAsync.when(
        loading: () => const LoadingState(),
        error: (err, _) => ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(allFaultsProvider),
        ),
        data: (allFaults) {
          final filtered = allFaults.where((f) {
            if (_filterIndex == 1) return !f.isResolved;
            if (_filterIndex == 2) return f.isResolved;
            return true; // All
          }).toList();

          if (filtered.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              message: 'Bu kategoride arıza bulunamadı.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allFaultsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final fault = filtered[index];
                return _FaultCard(fault: fault, elevators: elevatorsAsync);
              },
            ),
          );
        },
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }
}

class _FaultCard extends StatelessWidget {
  const _FaultCard({required this.fault, required this.elevators});

  final FaultReportModel fault;
  final AsyncValue<dynamic> elevators;

  @override
  Widget build(BuildContext context) {
    final isResolved = fault.isResolved;
    final dateStr = DateFormat(
      'dd MMM yyyy, HH:mm',
    ).format(fault.reportedAt.toLocal());

    // Attempt to find elevator name
    String elevatorName = 'Bilinmeyen Asansör';
    if (elevators is AsyncData) {
      final list = elevators.value as List;
      final matched = list.where((e) => e.id == fault.elevatorId).firstOrNull;
      if (matched != null) {
        elevatorName = matched.buildingName;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      elevation: 0,
      color: AppThemeColors.of(context).surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/fault/${fault.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isResolved
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isResolved
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      color: isResolved ? AppColors.success : AppColors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          elevatorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: AppColors.outline,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isResolved
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isResolved ? 'ÇÖZÜLDÜ' : 'AÇIK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isResolved ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                fault.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppThemeColors.of(context).onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/empty_state.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/models/checklist_item_model.dart';
import 'package:asansor/features/maintenance/views/widgets/maintenance_premium_panel.dart';
import 'package:asansor/l10n/app_localizations.dart';

class MaintenanceChecklistProgressCard extends StatelessWidget {
  const MaintenanceChecklistProgressCard({
    super.key,
    required this.checkedItems,
    required this.checklistAsync,
  });

  final Map<String, bool> checkedItems;
  final AsyncValue<List<ChecklistItemModel>> checklistAsync;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final activeItems = checklistAsync.maybeWhen(
      data: (items) => items.where((item) => item.isActive).toList(),
      orElse: () => const <ChecklistItemModel>[],
    );
    final total = activeItems.length;
    final checked = activeItems
        .where((item) => checkedItems[item.id] == true)
        .length;
    final progress = total == 0 ? 0.0 : checked / total;

    return MaintenancePremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Checklist İlerlemesi',
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: textTheme.titleLarge?.copyWith(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colors.surfaceContainer,
              color: AppColors.accentGold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$checked / $total kontrol tamamlandı',
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class MaintenanceChecklistPanel extends StatelessWidget {
  const MaintenanceChecklistPanel({
    super.key,
    required this.checklistAsync,
    required this.checkedItems,
    required this.onToggle,
  });

  final AsyncValue<List<ChecklistItemModel>> checklistAsync;
  final Map<String, bool> checkedItems;
  final void Function(String id, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return MaintenancePremiumPanel(
      title: l10n.maintenanceChecklistSection,
      icon: Icons.checklist_rounded,
      borderColor: colors.surfaceContainerHigh,
      child: checklistAsync.when(
        data: (items) {
          final activeItems = items.where((i) => i.isActive).toList();
          if (activeItems.isEmpty) {
            return EmptyState(
              icon: Icons.checklist_rtl_rounded,
              message: l10n.maintenanceChecklistEmpty,
            );
          }

          return Column(
            children: [
              for (final item in activeItems)
                _ChecklistRow(
                  item: item,
                  isChecked: checkedItems[item.id] == true,
                  onToggle: (value) => onToggle(item.id, value),
                ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LoadingState(),
        ),
        error: (err, stack) => ErrorState(
          message: l10n.maintenanceChecklistLoadError(err.toString()),
          onRetry: () {},
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.isChecked,
    required this.onToggle,
  });

  final ChecklistItemModel item;
  final bool isChecked;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => onToggle(!isChecked),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isChecked
              ? colors.primaryFixed.withValues(alpha: 0.34)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isChecked
                ? colors.primary.withValues(alpha: 0.16)
                : colors.outlineVariant.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isChecked,
              onChanged: (value) => onToggle(value ?? false),
              activeColor: colors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.description,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

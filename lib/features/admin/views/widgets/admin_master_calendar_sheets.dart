import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/app_section_header.dart';
import 'package:asansor/features/admin/models/schedule_with_details.dart';
import 'package:asansor/features/admin/providers/admin_providers.dart';

class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key, required this.allSchedules});

  final List<ScheduleWithDetails> allSchedules;

  static const _statusOptions = [
    ('', 'Tümü'),
    ('pending', 'Bekliyor'),
    ('in_progress', 'Devam Ediyor'),
    ('completed', 'Tamamlandı'),
    ('cancelled', 'İptal Edildi'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(masterCalendarFilterProvider);
    final notifier = ref.read(masterCalendarFilterProvider.notifier);

    final seen = <String>{};
    final technicians = <MapEntry<String, String>>[];
    for (final schedule in allSchedules) {
      if (schedule.technicianId.isNotEmpty && seen.add(schedule.technicianId)) {
        technicians.add(
          MapEntry(schedule.technicianId, schedule.technicianName),
        );
      }
    }
    technicians.sort((a, b) => a.value.compareTo(b.value));

    final colors = AppThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                children: [
                  Text(
                    'Filtrele',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (filter.isActive)
                    TextButton(
                      onPressed: notifier.clear,
                      child: Text(
                        'Temizle',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.outline),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (technicians.isNotEmpty) ...[
                const AppSectionHeader(title: 'TEKNİSYEN'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChipItem(
                      label: 'Tümü',
                      selected: filter.technicianId == null,
                      onSelected: () => notifier.setTechnician(null),
                    ),
                    for (final technician in technicians)
                      _FilterChipItem(
                        label: technician.value,
                        selected: filter.technicianId == technician.key,
                        onSelected: () => notifier.setTechnician(
                          filter.technicianId == technician.key
                              ? null
                              : technician.key,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: colors.outlineVariant, height: 1),
                const SizedBox(height: AppSpacing.md),
              ],
              const AppSectionHeader(title: 'DURUM'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in _statusOptions)
                    _FilterChipItem(
                      label: label,
                      selected: (filter.status ?? '') == value,
                      onSelected: () =>
                          notifier.setStatus(value.isEmpty ? null : value),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return FilterChip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: colors.primary.withValues(alpha: 0.1),
      checkmarkColor: colors.primary,
      side: BorderSide(
        color: selected
            ? colors.primary.withValues(alpha: 0.4)
            : colors.outlineVariant,
      ),
      backgroundColor: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

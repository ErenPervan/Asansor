import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/app_form_field.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/models/checklist_item_model.dart';
import 'package:asansor/features/admin/providers/checklist_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChecklistManagementView extends ConsumerWidget {
  const ChecklistManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final checklistAsync = ref.watch(checklistProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Geri',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Kontrol Listesi',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.primaryDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(checklistProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: () async {
          ref.invalidate(checklistProvider);
          await ref.read(checklistProvider.future);
        },
        child: checklistAsync.when(
          loading: () => const LoadingState(count: 5, height: 92),
          error: (err, _) => _ErrorState(
            message: err.toString(),
            onRetry: () => ref.invalidate(checklistProvider),
          ),
          data: (items) => _ChecklistContent(
            items: items,
            onAdd: () => _showItemSheet(context, ref),
            onEdit: (item) => _showItemSheet(context, ref, item: item),
            onToggle: (item, value) => ref
                .read(checklistProvider.notifier)
                .toggleActiveStatus(item.id, value),
            onDelete: (item) => _confirmDelete(context, ref, item),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemSheet(context, ref),
        backgroundColor: colors.primaryDark,
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.add_task_rounded),
        label: Text(
          'Yeni Kalem',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors.onPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  void _showItemSheet(
    BuildContext context,
    WidgetRef ref, {
    ChecklistItemModel? item,
  }) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isEdit = item != null;
    final labelCtrl = TextEditingController(text: item?.label ?? '');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.16),
                  blurRadius: 34,
                  offset: const Offset(0, -12),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.outlineVariant,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.primaryFixed.withValues(
                                alpha: 0.72,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              isEdit
                                  ? Icons.edit_note_rounded
                                  : Icons.add_task_rounded,
                              color: colors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit
                                      ? 'Kontrol Kalemini Düzenle'
                                      : 'Yeni Kontrol Kalemi',
                                  style: textTheme.titleLarge?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Bakım formunda teknisyene gösterilecek madde.',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Kapat',
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppFormField(
                        controller: labelCtrl,
                        label: 'Kalem Adı',
                        hint: 'Örn: Fren balata kontrolü',
                        prefixIcon: const Icon(Icons.label_outline_rounded),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Zorunlu alan'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        label: 'Açıklama',
                        hint: 'Teknisyen için kontrol talimatı...',
                        prefixIcon: const Icon(Icons.description_outlined),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Zorunlu alan'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: colors.outlineVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'İptal',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;
                                if (isEdit) {
                                  ref
                                      .read(checklistProvider.notifier)
                                      .updateItem(
                                        item.id,
                                        labelCtrl.text.trim(),
                                        descCtrl.text.trim(),
                                      );
                                } else {
                                  ref
                                      .read(checklistProvider.notifier)
                                      .addItem(
                                        labelCtrl.text.trim(),
                                        descCtrl.text.trim(),
                                      );
                                }
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEdit
                                          ? 'Kalem güncellendi'
                                          : 'Yeni kalem eklendi',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: Icon(
                                isEdit ? Icons.save_rounded : Icons.add_rounded,
                              ),
                              label: Text(isEdit ? 'Kaydet' : 'Kalemi Ekle'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: colors.primaryDark,
                                foregroundColor: colors.onPrimary,
                                textStyle: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ChecklistItemModel item,
  ) {
    final colors = AppThemeColors.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 36),
        title: const Text('Kalemi Sil'),
        content: Text(
          '"${item.label}" kalıcı olarak silinecek. Bu işlem bakım formundaki şablondan kaldırır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(checklistProvider.notifier).deleteItem(item.id);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kalem silindi'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

class _ChecklistContent extends StatelessWidget {
  const _ChecklistContent({
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final List<ChecklistItemModel> items;
  final VoidCallback onAdd;
  final ValueChanged<ChecklistItemModel> onEdit;
  final void Function(ChecklistItemModel item, bool value) onToggle;
  final ValueChanged<ChecklistItemModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final active = items.where((item) => item.isActive).toList();
    final inactive = items.where((item) => !item.isActive).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            110,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProtocolHeader(
                      totalCount: items.length,
                      activeCount: active.length,
                      inactiveCount: inactive.length,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (items.isEmpty)
                      _EmptyState(onAdd: onAdd)
                    else ...[
                      _SummaryGrid(
                        totalCount: items.length,
                        activeCount: active.length,
                        inactiveCount: inactive.length,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (active.isNotEmpty)
                        _ChecklistSection(
                          title: 'Aktif Kalemler',
                          subtitle: 'Bakım formunda kullanılan maddeler',
                          count: active.length,
                          icon: Icons.check_circle_rounded,
                          tone: _SectionTone.active,
                          items: active,
                          onEdit: onEdit,
                          onToggle: onToggle,
                          onDelete: onDelete,
                        ),
                      if (active.isNotEmpty && inactive.isNotEmpty)
                        const SizedBox(height: AppSpacing.lg),
                      if (inactive.isNotEmpty)
                        _ChecklistSection(
                          title: 'Pasif Kalemler',
                          subtitle:
                              'Geçici olarak bakım formundan kaldırılanlar',
                          count: inactive.length,
                          icon: Icons.block_rounded,
                          tone: _SectionTone.inactive,
                          items: inactive,
                          onEdit: onEdit,
                          onToggle: onToggle,
                          onDelete: onDelete,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProtocolHeader extends StatelessWidget {
  const _ProtocolHeader({
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
  });

  final int totalCount;
  final int activeCount;
  final int inactiveCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

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
              Icons.fact_check_rounded,
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.checklist_rounded,
                      color: colors.onPrimary,
                    ),
                  ),
                  const Spacer(),
                  _CountBadge(label: 'Toplam', value: totalCount),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Maintenance Protocols',
                style: textTheme.headlineMedium?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Bakım formlarında kullanılan kontrol adımlarını yönetin.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _HeaderChip(label: 'Aktif', value: activeCount),
                  _HeaderChip(label: 'Pasif', value: inactiveCount),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        '$value $label',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.accentGold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
  });

  final int totalCount;
  final int activeCount;
  final int inactiveCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final cards = [
          _SummaryCard(
            label: 'Aktif Kalem',
            value: activeCount.toString(),
            icon: Icons.check_circle_rounded,
            color: AppThemeColors.of(context).success,
          ),
          _SummaryCard(
            label: 'Pasif Kalem',
            value: inactiveCount.toString(),
            icon: Icons.block_rounded,
            color: AppThemeColors.of(context).outline,
          ),
          _SummaryCard(
            label: 'Kullanım Oranı',
            value: totalCount == 0
                ? '0%'
                : '${((activeCount / totalCount) * 100).round()}%',
            icon: Icons.insights_rounded,
            color: AppColors.accentGold,
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: AppSpacing.md),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i < cards.length - 1) const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.28),
        ),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

enum _SectionTone { active, inactive }

class _ChecklistSection extends StatelessWidget {
  const _ChecklistSection({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.tone,
    required this.items,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final _SectionTone tone;
  final List<ChecklistItemModel> items;
  final ValueChanged<ChecklistItemModel> onEdit;
  final void Function(ChecklistItemModel item, bool value) onToggle;
  final ValueChanged<ChecklistItemModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final accent = tone == _SectionTone.active
        ? colors.success
        : colors.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 2 : 1;
            final spacing = AppSpacing.md;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final item in items)
                  SizedBox(
                    width: width,
                    child: _ChecklistCard(
                      item: item,
                      onEdit: () => onEdit(item),
                      onToggle: (value) => onToggle(item, value),
                      onDelete: () => onDelete(item),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.item,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final ChecklistItemModel item;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final accent = item.isActive ? colors.primaryDark : colors.outline;
    final muted = !item.isActive;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(Icons.delete_outline_rounded, color: colors.error),
      ),
      child: Material(
        color: muted
            ? colors.surfaceContainerLowest.withValues(alpha: 0.72)
            : colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(minHeight: 186),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: muted
                    ? colors.outlineVariant.withValues(alpha: 0.32)
                    : colors.primary.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: muted ? 0.025 : 0.06),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: muted ? 0.08 : 0.11),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.isActive
                            ? Icons.settings_suggest_rounded
                            : Icons.pause_circle_outline_rounded,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: muted
                                      ? colors.onSurfaceVariant
                                      : colors.onSurface,
                                  fontWeight: FontWeight.w900,
                                  decoration: muted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.isActive ? 'Aktif protokol' : 'Pasif protokol',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: muted
                                      ? colors.outline
                                      : AppColors.accentGold,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: item.isActive,
                      onChanged: onToggle,
                      activeTrackColor: colors.primary,
                      inactiveTrackColor: colors.surfaceContainer,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  item.description.isEmpty
                      ? 'Bu kalem için açıklama girilmemiş.'
                      : item.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: muted ? colors.outline : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _IconAction(
                      icon: Icons.edit_rounded,
                      tooltip: 'Düzenle',
                      color: colors.primaryDark,
                      onTap: onEdit,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _IconAction(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Sil',
                      color: colors.error,
                      onTap: onDelete,
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

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: colors.primaryFixed.withValues(alpha: 0.72),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.playlist_add_rounded,
              color: colors.primaryDark,
              size: 38,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Henüz kontrol kalemi yok',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bakım formlarında kullanılacak ilk kontrol adımını ekleyin.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('İlk Kalemi Ekle'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primaryDark,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: 80),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, color: colors.error, size: 44),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Kontrol listesi yüklenemedi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

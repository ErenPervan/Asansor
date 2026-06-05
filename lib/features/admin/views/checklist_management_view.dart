import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_form_field.dart';
import '../../../core/widgets/loading_state.dart';
import '../models/checklist_item_model.dart';
import '../providers/checklist_provider.dart';

/// Kontrol Listesi Yönetim Ekranı
///
/// Admin kullanıcının bakım kontrol kalemlerini (checklist items)
/// eklemesine, düzenlemesine, aktif/pasif yapmasına ve silmesine olanak tanır.
class ChecklistManagementView extends ConsumerWidget {
  const ChecklistManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final checklistAsync = ref.watch(checklistProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          // ── Gradient AppBar ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: 56,
                bottom: 16,
                right: 16,
              ),
              title: Text(
                'Kontrol Listesi',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.surface,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.primary, colors.primaryDark],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Icon(
                        Icons.checklist_rtl_rounded,
                        size: 160,
                        color: colors.surface.withValues(alpha: 0.08),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child:
                            checklistAsync.whenOrNull(
                              data: (items) => Text(
                                '${items.length} kalem',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.surface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ) ??
                            const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: colors.surface),
              tooltip: 'Geri',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────
          checklistAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(onAdd: () => _showItemSheet(context, ref)),
                );
              }

              final active = items.where((e) => e.isActive).toList();
              final inactive = items.where((e) => !e.isActive).toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                sliver: SliverList.list(
                  children: [
                    // Active section
                    if (active.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Aktif Kalemler',
                        count: active.length,
                        color: colors.success,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...active.map(
                        (item) => _ChecklistCard(
                          item: item,
                          onTap: () => _showItemSheet(context, ref, item: item),
                          onToggle: (val) => ref
                              .read(checklistProvider.notifier)
                              .toggleActiveStatus(item.id, val),
                          onDelete: () => _confirmDelete(context, ref, item),
                        ),
                      ),
                    ],

                    // Inactive section
                    if (inactive.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _SectionHeader(
                        title: 'Pasif Kalemler',
                        count: inactive.length,
                        color: colors.outline,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...inactive.map(
                        (item) => _ChecklistCard(
                          item: item,
                          onTap: () => _showItemSheet(context, ref, item: item),
                          onToggle: (val) => ref
                              .read(checklistProvider.notifier)
                              .toggleActiveStatus(item.id, val),
                          onDelete: () => _confirmDelete(context, ref, item),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: LoadingState(count: 5, height: 80),
            ),
            error: (err, _) => SliverFillRemaining(
              child: _ErrorState(
                message: err.toString(),
                onRetry: () => ref.invalidate(checklistProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemSheet(context, ref),
        backgroundColor: colors.primary,
        foregroundColor: colors.surface,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Yeni Kalem',
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Bottom Sheet — Add / Edit ──────────────────────────────────────────────

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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXxl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.primaryFixed,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                            ),
                            child: Icon(
                              isEdit
                                  ? Icons.edit_note_rounded
                                  : Icons.add_task_rounded,
                              color: colors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isEdit ? 'Kalemi Düzenle' : 'Yeni Kalem Ekle',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Label field
                      AppFormField(
                        controller: labelCtrl,
                        label: 'Kalem Adı',
                        hint: 'Ör: Fren kontrolü',
                        prefixIcon: const Icon(Icons.label_outline_rounded),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Zorunlu alan'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Description field
                      AppFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        label: 'Açıklama',
                        hint: 'Kontrol adımının detaylı açıklaması...',
                        prefixIcon: const Icon(Icons.description_outlined),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Zorunlu alan'
                            : null,
                      ),
                      const SizedBox(height: 28),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(color: colors.outlineVariant),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                ),
                              ),
                              child: Text(
                                'İptal',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                Navigator.pop(ctx);
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
                              label: Text(
                                isEdit ? 'Kaydet' : 'Ekle',
                                style: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: colors.primary,
                                foregroundColor: colors.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  // ── Delete confirmation ────────────────────────────────────────────────────

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ChecklistItemModel item,
  ) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 36),
        title: const Text('Kalemi Sil'),
        content: RichText(
          text: TextSpan(
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
            children: [
              const TextSpan(
                text: 'Bu kontrol kalemi kalıcı olarak silinecek:\n',
              ),
              TextSpan(
                text: '"${item.label}"',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(checklistProvider.notifier).deleteItem(item.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kalem silindi'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.surface,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Private Widgets ──────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

/// Section header with item count chip
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Checklist card with side-stripe accent and swipe-to-delete.
class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.item,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final ChecklistItemModel item;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final stripeColor = item.isActive ? colors.success : colors.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          onDelete();
          return false; // dialog handles delete
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: colors.errorContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(Icons.delete_outline_rounded, color: colors.error),
        ),
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: BorderSide(color: colors.outlineVariant, width: 0.8),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Side stripe
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: stripeColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppSpacing.radiusMd),
                        bottomLeft: Radius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: item.isActive
                                  ? colors.onSurface
                                  : colors.outline,
                              decoration: item.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: item.isActive
                                    ? colors.onSurfaceVariant
                                    : colors.outline,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Toggle switch
                  Switch.adaptive(
                    value: item.isActive,
                    onChanged: onToggle,
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: colors.surfaceContainer,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state when no checklist items exist.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colors.primaryFixed,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.playlist_add_rounded,
                size: 48,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Henüz kontrol kalemi yok',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Bakım kontrol listesine kalem ekleyerek\nteknisyenlerin iş kalitesini artırın.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'İlk Kalemi Ekle',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state with retry action.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: colors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Bir hata oluştu',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
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
    );
  }
}

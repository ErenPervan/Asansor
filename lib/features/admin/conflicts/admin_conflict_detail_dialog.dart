import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/conflicts/admin_conflict_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminConflictDetailDialog extends ConsumerWidget {
  const AdminConflictDetailDialog({super.key, required this.report});

  final ConflictReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final isLoading = ref.watch(adminConflictProvider).isLoading;
    final notifier = ref.read(adminConflictProvider.notifier);
    final displayKeys = _displayKeys(report);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.18),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _DialogHeader(report: report),
              Expanded(
                child: Container(
                  color: colors.surfaceContainerLow,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final local = _PayloadPanel(
                        title: 'Yerel Değişiklik',
                        subtitle: 'Teknisyen cihazından gelen kayıt',
                        icon: Icons.smartphone_rounded,
                        payload: report.localPayload,
                        keys: displayKeys,
                        accent: colors.primaryDark,
                      );
                      final remote = _PayloadPanel(
                        title: 'Uzak Durum',
                        subtitle: 'Sunucudaki mevcut kayıt',
                        icon: Icons.cloud_rounded,
                        payload: report.remotePayload,
                        keys: displayKeys,
                        accent: colors.secondary,
                      );

                      if (constraints.maxWidth < 700) {
                        return ListView(
                          children: [
                            local,
                            const SizedBox(height: AppSpacing.md),
                            remote,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: local),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: remote),
                        ],
                      );
                    },
                  ),
                ),
              ),
              _DialogActions(
                isLoading: isLoading,
                onKeepRemote: () async {
                  await notifier.resolveDiscardLocal(report);
                  if (context.mounted) Navigator.of(context).pop();
                },
                onAcceptLocal: () async {
                  await notifier.resolveForceLocal(report);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.report});

  final ConflictReport report;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final title = report.buildingName ?? report.elevatorId;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primaryDark,
        border: Border(
          bottom: BorderSide(color: colors.onPrimary.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.sync_problem_rounded, color: colors.onPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Çakışma Detayı',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  'Teknisyen: ${report.technicianName ?? "Bilinmeyen Teknisyen"}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: colors.onPrimary),
            tooltip: 'Kapat',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _PayloadPanel extends StatelessWidget {
  const _PayloadPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.payload,
    required this.keys,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Map<String, dynamic> payload;
  final List<String> keys;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: keys.isEmpty
                ? _NoFields(accent: accent)
                : ListView.separated(
                    itemCount: keys.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final key = keys[index];
                      return _PayloadRow(
                        label: key.toUpperCase().replaceAll('_', ' '),
                        value: payload[key]?.toString() ?? '—',
                        accent: accent,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoFields extends StatelessWidget {
  const _NoFields({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Center(
      child: Text(
        'Gösterilecek alan yok',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PayloadRow extends StatelessWidget {
  const _PayloadRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.isLoading,
    required this.onKeepRemote,
    required this.onAcceptLocal,
  });

  final bool isLoading;
  final Future<void> Function() onKeepRemote;
  final Future<void> Function() onAcceptLocal;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.cloud_done_rounded),
              label: const Text('Sunucuyu Koru'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
                foregroundColor: colors.primaryDark,
                side: BorderSide(
                  color: colors.primaryDark.withValues(alpha: 0.28),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: isLoading ? null : onKeepRemote,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton.icon(
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.offline_bolt_rounded),
              label: const Text('Yereli Kabul Et'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 50),
                backgroundColor: colors.primaryDark,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: isLoading ? null : onAcceptLocal,
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _displayKeys(ConflictReport report) {
  const excluded = {'id', 'base_version', 'updated_at', 'version'};
  return <String>{
    ...report.localPayload.keys,
    ...report.remotePayload.keys,
  }.where((key) => !excluded.contains(key)).toList()..sort();
}

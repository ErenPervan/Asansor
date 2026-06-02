import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_conflict_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class AdminConflictDetailDialog extends ConsumerWidget {
  const AdminConflictDetailDialog({super.key, required this.report});
  final ConflictReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(adminConflictProvider).isLoading;
    final notifier = ref.read(adminConflictProvider.notifier);
    final colors = AppThemeColors.of(context);

    // Get unique keys from both payloads
    final allKeys = <String>{
      ...report.localPayload.keys,
      ...report.remotePayload.keys,
    };
    final excludedKeys = {'id', 'base_version', 'updated_at', 'version'};
    final displayKeys = allKeys.where((k) => !excludedKeys.contains(k)).toList()
      ..sort();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Çakışma Detayı: ${report.buildingName ?? report.elevatorId}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Teknisyen: ${report.technicianName ?? "Bilinmeyen Teknisyen"}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PayloadColumn(
                      title: 'Yerel Değişiklik (Teknisyen)',
                      payload: report.localPayload,
                      keys: displayKeys,
                      bgColor: colors.errorContainer,
                      labelColor: colors.onErrorContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _PayloadColumn(
                      title: 'Uzak Durum (Sunucu)',
                      payload: report.remotePayload,
                      keys: displayKeys,
                      bgColor: colors.blueSoft,
                      labelColor: colors.navyMid,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_done_outlined),
                  label: const Text('Uzakı Koru (Yereli Yoksay)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.navyMid,
                    side: BorderSide(color: colors.navyMid),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          await notifier.resolveDiscardLocal(report);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                ),
                const SizedBox(width: AppSpacing.md),
                FilledButton.icon(
                  icon: isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onError,
                          ),
                        )
                      : const Icon(Icons.warning_amber_rounded),
                  label: const Text('Yereli Kabul Et (Zorla Güncelle)'),
                  style: FilledButton.styleFrom(backgroundColor: colors.error),
                  onPressed: isLoading
                      ? null
                      : () async {
                          await notifier.resolveForceLocal(report);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PayloadColumn extends StatelessWidget {
  const _PayloadColumn({
    required this.title,
    required this.payload,
    required this.keys,
    required this.bgColor,
    required this.labelColor,
  });

  final String title;
  final Map<String, dynamic> payload;
  final List<String> keys;
  final Color bgColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: labelColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.code, color: labelColor, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: keys.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final key = keys[index];
                final value = payload[key]?.toString() ?? '—';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key.toUpperCase().replaceAll('_', ' '),
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: labelColor.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppThemeColors.dark.onSurface 
                            : AppThemeColors.light.onSurface,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

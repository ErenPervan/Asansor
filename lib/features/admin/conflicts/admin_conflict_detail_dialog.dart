import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_conflict_provider.dart';

const _error = Color(0xFFBA1A1A);
const _localBg = Color(0xFFFFF1F2);
const _localLabel = Color(0xFF93000A);
const _remoteBg = Color(0xFFF0F4FF);
const _remoteLabel = Color(0xFF0D4686);

class AdminConflictDetailDialog extends ConsumerWidget {
  const AdminConflictDetailDialog({super.key, required this.report});
  final ConflictReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(adminConflictProvider).isLoading;
    final notifier = ref.read(adminConflictProvider.notifier);

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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Çakışma Detayı: ${report.buildingName ?? report.elevatorId}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF191C1D),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Teknisyen: ${report.technicianName ?? "Bilinmeyen Teknisyen"}',
              style: const TextStyle(
                color: Color(0xFF424752),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PayloadColumn(
                      title: 'Yerel Değişiklik (Teknisyen)',
                      payload: report.localPayload,
                      keys: displayKeys,
                      bgColor: _localBg,
                      labelColor: _localLabel,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _PayloadColumn(
                      title: 'Uzak Durum (Sunucu)',
                      payload: report.remotePayload,
                      keys: displayKeys,
                      bgColor: _remoteBg,
                      labelColor: _remoteLabel,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_done_outlined),
                  label: const Text('Uzakı Koru (Yereli Yoksay)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _remoteLabel,
                    side: const BorderSide(color: _remoteLabel),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          await notifier.resolveDiscardLocal(report);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.warning_amber_rounded),
                  label: const Text('Yereli Kabul Et (Zorla Güncelle)'),
                  style: FilledButton.styleFrom(backgroundColor: _error),
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
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: labelColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.code, color: labelColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: labelColor,
                  fontSize: 14,
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
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: labelColor.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF191C1D),
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

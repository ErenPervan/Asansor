import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/services/pdf_service.dart';
import 'package:asansor/core/widgets/info_card.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/maintenance/providers/maintenance_providers.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import 'package:asansor/core/widgets/animations/fade_in_slide.dart';

class MaintenanceHistorySection extends ConsumerStatefulWidget {
  const MaintenanceHistorySection({
    super.key,
    required this.elevatorId,
    required this.elevator,
  });

  final String elevatorId;
  final ElevatorModel elevator;

  @override
  ConsumerState<MaintenanceHistorySection> createState() =>
      MaintenanceHistorySectionState();
}

class MaintenanceHistorySectionState
    extends ConsumerState<MaintenanceHistorySection> {
  bool _generatingPdf = false;

  Future<void> _generateAndPreviewPdf() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      final logs = await repo.getLogsForReport(widget.elevatorId);
      final doc = await PdfService().generateElevatorReport(
        widget.elevator,
        logs,
      );
      final bytes = await doc.save();
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF oluşturulamadı: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(logsByElevatorProvider(widget.elevatorId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bakım Geçmişi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            Row(
              children: [
                // ── PDF Report button ──────────────────────────────────
                Tooltip(
                  message: 'PDF Rapor Oluştur (Son 6 Ay)',
                  child: _generatingPdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 22,
                            color: AppColors.primary,
                          ),
                          onPressed: _generateAndPreviewPdf,
                        ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Yenile',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.refresh,
                    size: 18,
                    color: AppColors.outline,
                  ),
                  onPressed: () =>
                      ref.invalidate(logsByElevatorProvider(widget.elevatorId)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Timeline content
        logsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              err.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(color: AppColors.onErrorContainer),
            ),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 40,
                        color: AppColors.outlineVariant,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Henüz bakım kaydı yok.',
                        style: TextStyle(
                          color: AppColors.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Timeline list — vertical line drawn as left-column Container
            return Column(
              children: logs.asMap().entries.map((entry) {
                return FadeInSlide(
                  index: entry.key,
                  child: TimelineItem(
                    log: entry.value,
                    isLast: entry.key == logs.length - 1,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Timeline item ─────────────────────────────────────────────────────────────

class TimelineItem extends StatelessWidget {
  const TimelineItem({super.key, required this.log, required this.isLast});

  final MaintenanceLogModel log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight ensures the connecting line fills the full card height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left column: dot + connector line ──────────────────────────
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 6),
                // Dot with ring effect (ring-4 ring-surface → white border)
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    // Approved → primary dot; pending → outline-variant dot
                    color: log.isApproved
                        ? AppColors.primary
                        : AppColors.outlineVariant,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 3),
                  ),
                ),
                // Connector line (hidden on last item)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),

          // ── Right column: card ─────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 16, bottom: isLast ? 0 : 24),
              child: TimelineCard(log: log),
            ),
          ),
        ],
      ),
    );
  }
}

class TimelineCard extends StatelessWidget {
  const TimelineCard({super.key, required this.log});

  final MaintenanceLogModel log;

  @override
  Widget build(BuildContext context) {
    final dateStr = _fmtDate(log.maintenanceDate);

    return InfoCard(
      padding: const EdgeInsets.all(20),
      radius: 12,
      backgroundColor: AppColors.surfaceContainerLowest,
      borderColor: Colors.transparent,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + technician row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  // Approved uses primary colour, pending uses outline
                  color: log.isApproved ? AppColors.primary : AppColors.outline,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      log.technicianName ??
                          (log.technicianId.length > 8
                              ? log.technicianId.substring(0, 8)
                              : log.technicianId),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Notes text (italic like the Stitch design)
          Text(
            '"${log.notes ?? 'Not belirtilmemiş'}"',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Chips row
          Row(
            children: [
              StatusChip(
                label: log.isApproved ? 'ONAYLANDI' : 'BEKLİYOR',
                bg: log.isApproved
                    ? AppColors
                          .errorContainer // secondary-container
                    : AppColors.surfaceContainer,
                fg: log.isApproved
                    ? AppColors
                          .onErrorContainer // on-secondary-container
                    : AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

final List<String> _monthsTr = [
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
];

String _fmtDate(DateTime dt) {
  final localDt = dt.toLocal();
  final hour = localDt.hour.toString().padLeft(2, '0');
  final minute = localDt.minute.toString().padLeft(2, '0');
  return '${localDt.day} ${_monthsTr[localDt.month - 1]} ${localDt.year}, $hour:$minute';
}

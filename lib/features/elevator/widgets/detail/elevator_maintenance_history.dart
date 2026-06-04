import 'package:asansor/core/theme/app_spacing.dart';
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
          backgroundColor: AppThemeColors.of(context).error,
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(logsByElevatorProvider(widget.elevatorId));
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bakım Geçmişi',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            Row(
              children: [
                // ─â‚¬─â‚¬ PDF Report button ─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬
                Tooltip(
                  message: 'PDF Rapor Oluştur (Son 6 Ay)',
                  child: _generatingPdf
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        )
                      : IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 22,
                            color: colors.primary,
                          ),
                          onPressed: _generateAndPreviewPdf,
                        ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: 'Yenile',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.refresh, size: 18, color: colors.outline),
                  onPressed: () =>
                      ref.invalidate(logsByElevatorProvider(widget.elevatorId)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Timeline content
        logsAsync.when(
          loading: () => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(color: colors.primary),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              err.toString().replaceFirst('Exception: ', ''),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onErrorContainer),
            ),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 40,
                        color: colors.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz bakım kaydı yok.',
                        style: textTheme.titleSmall?.copyWith(
                          color: colors.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Timeline list Ã¢â‚¬â€ vertical line drawn as left-column Container
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

// ─â‚¬─â‚¬ Timeline item ─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬

class TimelineItem extends StatelessWidget {
  const TimelineItem({super.key, required this.log, required this.isLast});

  final MaintenanceLogModel log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    // IntrinsicHeight ensures the connecting line fills the full card height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─â‚¬─â‚¬ Left column: dot + connector line ─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 6),
                // Dot with ring effect (ring-4 ring-surface ─ â€™ white border)
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    // Approved ─ â€™ primary dot; pending ─ â€™ outline-variant dot
                    color: log.isApproved
                        ? colors.primary
                        : colors.outlineVariant,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.background, width: 3),
                  ),
                ),
                // Connector line (hidden on last item)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: colors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),

          // ─â‚¬─â‚¬ Right column: card ─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬
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
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final dateStr = _fmtDate(log.maintenanceDate);

    return InfoCard(
      padding: const EdgeInsets.all(20),
      radius: 12,
      backgroundColor: colors.surfaceContainerLowest,
      borderColor: Colors.transparent,
      boxShadow: [
        BoxShadow(
          color: colors.onSurface.withValues(alpha: 0.04),
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
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  // Approved uses primary colour, pending uses outline
                  color: log.isApproved ? colors.primary : colors.outline,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      log.technicianName ??
                          (log.technicianId.length > 8
                              ? log.technicianId.substring(0, 8)
                              : log.technicianId),
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.onSurfaceVariant,
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
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
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
                    ? colors
                          .errorContainer // secondary-container
                    : colors.surfaceContainer,
                fg: log.isApproved
                    ? colors
                          .onErrorContainer // on-secondary-container
                    : colors.onSurfaceVariant,
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
  'Şub',
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

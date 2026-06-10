import 'package:asansor/core/services/pdf_service.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/animations/fade_in_slide.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import 'package:asansor/features/maintenance/providers/maintenance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primaryFixed.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.timeline_rounded,
                  color: colors.primaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Servis Geçmişi',
                  style: textTheme.titleLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Tooltip(
                message: 'PDF Rapor Oluştur (Son 6 Ay)',
                child: _generatingPdf
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.picture_as_pdf_outlined,
                          color: colors.primaryDark,
                        ),
                        onPressed: _generateAndPreviewPdf,
                      ),
              ),
              IconButton(
                tooltip: 'Yenile',
                icon: Icon(Icons.refresh_rounded, color: colors.outline),
                onPressed: () =>
                    ref.invalidate(logsByElevatorProvider(widget.elevatorId)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          logsAsync.when(
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(color: colors.primary),
              ),
            ),
            error: (err, _) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                err.toString().replaceFirst('Exception: ', ''),
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return _EmptyTimeline();
              }

              return Column(
                children: [
                  for (var i = 0; i < logs.length; i++)
                    FadeInSlide(
                      index: i,
                      child: TimelineItem(
                        log: logs[i],
                        isLast: i == logs.length - 1,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 42, color: colors.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'Henüz bakım kaydı yok.',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.outline,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class TimelineItem extends StatelessWidget {
  const TimelineItem({super.key, required this.log, required this.isLast});

  final MaintenanceLogModel log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: log.isApproved
                        ? colors.primaryDark
                        : colors.outlineVariant,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.surfaceContainerLowest,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.12),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: colors.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
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
    final technician =
        log.technicianName ??
        (log.technicianId.length > 8
            ? log.technicianId.substring(0, 8)
            : log.technicianId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: textTheme.labelMedium?.copyWith(
              color: log.isApproved ? colors.primaryDark : colors.outline,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            log.notes?.isNotEmpty == true
                ? log.notes!
                : 'Bakım notu belirtilmemiş.',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusChip(
                label: log.isApproved ? 'Onaylandı' : 'Bekliyor',
                bg: log.isApproved
                    ? colors.primaryFixed.withValues(alpha: 0.72)
                    : colors.surfaceContainerHigh,
                fg: log.isApproved
                    ? colors.primaryDark
                    : colors.onSurfaceVariant,
              ),
              StatusChip(
                label: 'Teknisyen: $technician',
                bg: colors.surfaceContainer,
                fg: colors.onSurfaceVariant,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: fg,
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

import 'package:asansor/core/constants/app_durations.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/empty_state.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/core/widgets/notification_rationale_sheet.dart';
import 'package:asansor/core/widgets/offline_banner.dart';
import 'package:asansor/features/auth/providers/auth_providers.dart';
import 'package:asansor/features/customer/providers/customer_portal_provider.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/widgets/detail/report_fault_sheet.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';

const _panelLine = Color(0xFFE1E8F0);

class CustomerDashboardView extends ConsumerStatefulWidget {
  const CustomerDashboardView({super.key});
  @override
  ConsumerState<CustomerDashboardView> createState() =>
      _CustomerDashboardViewState();
}

class _CustomerDashboardViewState extends ConsumerState<CustomerDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationRationaleSheet.checkAndShow(context);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(customerElevatorProvider);
    ref.invalidate(customerMaintenanceLogsProvider);
  }

  Future<void> _confirmSignOut() async {
    final colors = AppThemeColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Çıkış Yap'),
        content: const Text('Oturumu kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final elevatorAsync = ref.watch(customerElevatorProvider);
    final logsAsync = ref.watch(customerMaintenanceLogsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Icon(Icons.elevator_rounded, color: colors.primary),
            const SizedBox(width: 10),
            Text(
              'Asansör',
              style: textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _confirmSignOut,
            icon: Icon(Icons.logout_rounded, color: colors.error, size: 18),
            label: Text(
              'Çıkış',
              style: textTheme.labelLarge?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: elevatorAsync.when(
              loading: () => const LoadingState(),
              error: (err, _) => ErrorState(
                message: 'Asansör bilgisi alınamadı.\n$err',
                onRetry: () => ref.invalidate(customerElevatorProvider),
              ),
              data: (elevator) {
                if (elevator == null) {
                  return const EmptyState(
                    icon: Icons.elevator_outlined,
                    message: 'Size atanmış bir asansör bulunamadı.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PageIntro(onRefresh: _refresh),
                              const SizedBox(height: AppSpacing.lg),
                              _ElevatorStatusCard(elevator: elevator),
                              const SizedBox(height: AppSpacing.lg),
                              _ReportFaultButton(elevatorId: elevator.id),
                              const SizedBox(height: 32),
                              _MaintenanceSection(
                                logsAsync: logsAsync,
                                onRetry: _refresh,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asansör Durumu',
                style: textTheme.headlineSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Güncel operasyonel veriler ve servis geçmişi.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onRefresh,
          tooltip: 'Yenile',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _ElevatorStatusCard extends StatelessWidget {
  const _ElevatorStatusCard({required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final status = _statusData(context, elevator.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelLine),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elevator.buildingName.isNotEmpty
                          ? elevator.buildingName
                          : 'Asansör',
                      style: textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      elevator.model ?? 'Yolcu asansörü',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Gauge(status: status),
          const SizedBox(height: AppSpacing.lg),
          Text(
            status.title,
            style: textTheme.headlineSmall?.copyWith(
              color: status.color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            status.description,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          _ElevatorFacts(elevator: elevator),
        ],
      ),
    );
  }

  static _StatusVisual _statusData(
    BuildContext context,
    ElevatorStatus status,
  ) {
    final colors = AppThemeColors.of(context);
    switch (status) {
      case ElevatorStatus.faulty:
        return _StatusVisual(
          label: 'Arızalı',
          title: 'Müdahale Gerekli',
          description:
              'Asansörde aktif arıza durumu var. Arıza bildirimi ve servis süreci takip ediliyor.',
          icon: Icons.warning_rounded,
          color: colors.error,
          surface: colors.errorContainer,
          progress: 0.28,
        );
      case ElevatorStatus.underMaintenance:
        return _StatusVisual(
          label: 'Bakımda',
          title: 'Bakım İşlemi Sürüyor',
          description:
              'Planlı bakım veya kontrol işlemi devam ediyor. Tamamlandığında durum güncellenecek.',
          icon: Icons.handyman_rounded,
          color: colors.warning,
          surface: colors.warningContainer,
          progress: 0.62,
        );
      case ElevatorStatus.inactive:
        return _StatusVisual(
          label: 'Devre Dışı',
          title: 'Kullanım Dışı',
          description:
              'Asansör şu an servis dışı. Yönetim veya teknik ekip yeniden devreye alma sürecini yürütebilir.',
          icon: Icons.not_interested_rounded,
          color: colors.onSurfaceVariant,
          surface: colors.surfaceContainerHigh,
          progress: 0.15,
        );
      case ElevatorStatus.active:
        return _StatusVisual(
          label: 'Aktif',
          title: 'Aktif ve Serviste',
          description:
              'Sistem parametreleri normal seviyelerde. Son durum verileri başarıyla alındı.',
          icon: Icons.elevator_rounded,
          color: colors.primary,
          surface: colors.primaryContainer,
          progress: 1,
        );
    }
  }
}

class _StatusVisual {
  const _StatusVisual({
    required this.label,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.surface,
    required this.progress,
  });

  final String label;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color surface;
  final double progress;
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.status});

  final _StatusVisual status;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      height: 164,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 164,
            height: 164,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 8,
              color: _panelLine,
              backgroundColor: _panelLine,
            ),
          ),
          SizedBox(
            width: 164,
            height: 164,
            child: CircularProgressIndicator(
              value: status.progress,
              strokeWidth: 8,
              color: status.color,
              backgroundColor: Colors.transparent,
              strokeCap: StrokeCap.round,
            ),
          ),
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: status.surface.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(status.icon, size: 48, color: status.color),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ElevatorFacts extends StatelessWidget {
  const _ElevatorFacts({required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeColors.of(context).background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelLine),
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          _FactItem(
            icon: Icons.monitor_weight_rounded,
            label: 'Kapasite',
            value: elevator.capacity == null
                ? 'Belirtilmedi'
                : '${elevator.capacity} kg',
          ),
          _FactItem(
            icon: Icons.calendar_month_rounded,
            label: 'Bakım Günü',
            value: elevator.maintenanceDay == null
                ? 'Belirtilmedi'
                : 'Her ay ${elevator.maintenanceDay}. gün',
          ),
          _FactItem(
            icon: Icons.location_on_rounded,
            label: 'Adres',
            value: elevator.address ?? 'Adres kaydı yok',
          ),
        ],
      ),
    );
  }
}

class _FactItem extends StatelessWidget {
  const _FactItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 230),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.outline,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                value,
                style: textTheme.labelMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportFaultButton extends StatelessWidget {
  const _ReportFaultButton({required this.elevatorId});

  final String elevatorId;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.error,
          foregroundColor: colors.onError,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            builder: (_) => ReportFaultSheet(elevatorId: elevatorId),
          );
        },
        icon: const Icon(Icons.report_problem_rounded, size: 24),
        label: Text(
          'Arıza Bildir',
          style: textTheme.titleSmall?.copyWith(
            color: colors.onError,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MaintenanceSection extends StatelessWidget {
  const _MaintenanceSection({required this.logsAsync, required this.onRetry});

  final AsyncValue<List<MaintenanceLogModel>> logsAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son Bakım Geçmişi',
          style: textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        logsAsync.when(
          loading: () => const LoadingState(shrinkWrap: true),
          error: (err, _) => ErrorState(
            message: 'Bakım geçmişi alınamadı.\n$err',
            onRetry: onRetry,
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return const EmptyState(
                icon: Icons.history_rounded,
                message: 'Henüz bakım kaydı bulunmuyor.',
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _panelLine),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: colors.outlineVariant),
                itemBuilder: (context, index) =>
                    _MaintenanceLogTile(log: logs[index]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MaintenanceLogTile extends ConsumerWidget {
  const _MaintenanceLogTile({required this.log});

  final MaintenanceLogModel log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final dateStr = DateFormat(
      'd MMMM y',
      'tr_TR',
    ).format(log.maintenanceDate.toLocal());
    final hasPdf = log.pdfUrl != null && log.pdfUrl!.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.build_circle_rounded, color: colors.primary),
      ),
      title: Text(
        log.notes != null && log.notes!.isNotEmpty
            ? log.notes!
            : 'Periyodik Bakım',
        style: textTheme.labelLarge?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w900,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                dateStr,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      trailing: hasPdf
          ? IconButton(
              tooltip: 'Raporu İndir',
              icon: Icon(Icons.picture_as_pdf_rounded, color: colors.error),
              onPressed: () => _openPdf(context, ref, log.pdfUrl!),
            )
          : null,
    );
  }

  Future<void> _openPdf(
    BuildContext context,
    WidgetRef ref,
    String pathOrUrl,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rapor açılıyor...'),
        duration: AppDurations.snackBarInfo,
      ),
    );
    try {
      final String url;
      if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
        url = pathOrUrl;
      } else {
        url = await ref
            .read(supabaseClientProvider)
            .storage
            .from('maintenance-reports')
            .createSignedUrl(pathOrUrl, 60 * 60);
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('Error opening PDF: $e');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF açılamadı.'),
          duration: AppDurations.snackBarError,
        ),
      );
    }
  }
}

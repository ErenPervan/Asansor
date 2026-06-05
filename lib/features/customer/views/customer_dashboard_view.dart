import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../core/enums/app_enums.dart';
import '../../elevator/models/elevator_model.dart';
import '../../maintenance/models/maintenance_log_model.dart';
import '../../elevator/widgets/detail/report_fault_sheet.dart';
import '../../../core/constants/app_durations.dart';
import '../providers/customer_portal_provider.dart';
import '../../../core/widgets/notification_rationale_sheet.dart';

class CustomerDashboardView extends ConsumerStatefulWidget {
  const CustomerDashboardView({super.key});

  @override
  ConsumerState<CustomerDashboardView> createState() => _CustomerDashboardViewState();
}

class _CustomerDashboardViewState extends ConsumerState<CustomerDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationRationaleSheet.checkAndShow(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final elevatorAsync = ref.watch(customerElevatorProvider);
    final logsAsync = ref.watch(customerMaintenanceLogsProvider);

    return Scaffold(
      backgroundColor: AppThemeColors.of(context).background,
      appBar: AppBar(
        title: Text(
          'Asansör Durumu',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: AppThemeColors.of(context).surface,
        foregroundColor: AppThemeColors.of(context).onSurface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Çıkış Yap',
            icon: Icon(Icons.logout, color: AppThemeColors.of(context).error),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Çıkış Yap'),
                  content: Text('Oturumu kapatmak istediğinize emin misiniz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('İptal'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppThemeColors.of(context).error,
                        foregroundColor: AppThemeColors.of(context).onError,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('Çıkış Yap'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authControllerProvider.notifier).signOut();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: elevatorAsync.when(
              data: (elevator) {
                if (elevator == null) {
                  return const EmptyState(
                    icon: Icons.elevator_outlined,
                    message: 'Size atanmış bir asansör bulunamadı.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(customerElevatorProvider);
                    ref.invalidate(customerMaintenanceLogsProvider);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _ElevatorHealthCard(elevator: elevator),
                      const SizedBox(height: AppSpacing.lg),
                      _ReportFaultButton(elevatorId: elevator.id),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Son Bakım Geçmişi',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppThemeColors.of(context).onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _MaintenanceLogList(
                        logsAsync: logsAsync,
                        onRetry: () {
                          ref.invalidate(customerElevatorProvider);
                          ref.invalidate(customerMaintenanceLogsProvider);
                        },
                      ),
                    ],
                  ),
                );
              },
              loading: () => const LoadingState(),
              error: (err, _) => ErrorState(
                message: 'Asansör bilgisi alınamadı.\n$err',
                onRetry: () => ref.invalidate(customerElevatorProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ElevatorHealthCard extends StatelessWidget {
  const _ElevatorHealthCard({required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final bool isFaulty = elevator.status == ElevatorStatus.faulty;
    final bool isUnderMaintenance =
        elevator.status == ElevatorStatus.underMaintenance;

    final colors = AppThemeColors.of(context);
    Color bgColor = colors.successContainer;
    Color iconColor = colors.success;
    IconData iconData = Icons.check_circle_outline;
    String statusText = 'Aktif ve Sorunsuz';

    if (isFaulty) {
      bgColor = colors.errorContainer;
      iconColor = colors.error;
      iconData = Icons.warning_amber_rounded;
      statusText = 'Arızalı';
    } else if (isUnderMaintenance) {
      bgColor = colors.warningContainer;
      iconColor = colors.warningLight;
      iconData = Icons.handyman_outlined;
      statusText = 'Bakımda';
    } else if (elevator.status == ElevatorStatus.inactive) {
      bgColor = colors.surfaceContainerHigh;
      iconColor = colors.onSurfaceVariant;
      iconData = Icons.not_interested_rounded;
      statusText = 'Devre Dışı';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, size: 72, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            elevator.buildingName.isNotEmpty
                ? elevator.buildingName
                : 'Asansör',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: iconColor.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportFaultButton extends StatelessWidget {
  const _ReportFaultButton({required this.elevatorId});

  final String elevatorId;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: colors.error,
        foregroundColor: colors.onError,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => ReportFaultSheet(elevatorId: elevatorId),
        );
      },
      icon: const Icon(Icons.report_problem_outlined, size: 28),
      label: Text(
        'Arıza Bildir',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MaintenanceLogList extends StatelessWidget {
  const _MaintenanceLogList({required this.logsAsync, required this.onRetry});

  final AsyncValue<List<MaintenanceLogModel>> logsAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            message: 'Henüz bakım kaydı bulunmuyor.',
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final log = logs[index];
            final dateStr = DateFormat(
              'dd MMMM yyyy',
            ).format(log.maintenanceDate.toLocal());
            final hasPdf = log.pdfUrl != null && log.pdfUrl!.isNotEmpty;

            return Container(
              decoration: BoxDecoration(
                color: AppThemeColors.of(context).surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppThemeColors.of(context).outlineVariant,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeColors.of(
                      context,
                    ).onSurface.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppThemeColors.of(context).surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.build_circle_outlined,
                    color: AppThemeColors.of(context).onSurfaceVariant,
                  ),
                ),
                title: Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  log.notes != null && log.notes!.isNotEmpty
                      ? log.notes!
                      : 'Periyodik Bakım',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppThemeColors.of(context).onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: hasPdf
                    ? IconButton(
                        icon: Icon(
                          Icons.picture_as_pdf,
                          color: AppThemeColors.of(context).error,
                        ),
                        tooltip: 'Raporu İndir',
                        onPressed: () async {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Rapor açılıyor...'),
                                duration: AppDurations.snackBarInfo,
                              ),
                            );
                          }
                          final uri = Uri.parse(log.pdfUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('PDF açılamadı.'),
                                  duration: AppDurations.snackBarError,
                                ),
                              );
                            }
                          }
                        },
                      )
                    : null,
              ),
            );
          },
        );
      },
      loading: () => const LoadingState(shrinkWrap: true),
      error: (err, _) => ErrorState(
        message: 'Bakım geçmişi alınamadı.\n$err',
        onRetry: onRetry,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../elevator/models/elevator_model.dart';
import '../../maintenance/models/maintenance_log_model.dart';
import '../../elevator/widgets/detail/report_fault_sheet.dart';
import '../../../core/constants/app_durations.dart';
import '../providers/customer_portal_provider.dart';

class CustomerDashboardView extends ConsumerWidget {
  const CustomerDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elevatorAsync = ref.watch(customerElevatorProvider);
    final logsAsync = ref.watch(customerMaintenanceLogsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Asansör Durumu',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: elevatorAsync.when(
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
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _ElevatorHealthCard(elevator: elevator),
                const SizedBox(height: 24),
                _ReportFaultButton(elevatorId: elevator.id),
                const SizedBox(height: 32),
                const Text(
                  'Son Bakım Geçmişi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
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
    );
  }
}

class _ElevatorHealthCard extends StatelessWidget {
  const _ElevatorHealthCard({required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final bool isFaulty = elevator.status == 'faulty';
    final bool isUnderMaintenance = elevator.status == 'under_maintenance';

    Color bgColor = AppColors.successContainer;
    Color iconColor = AppColors.success;
    IconData iconData = Icons.check_circle_outline;
    String statusText = 'Aktif ve Sorunsuz';

    if (isFaulty) {
      bgColor = AppColors.errorContainer;
      iconColor = AppColors.error;
      iconData = Icons.warning_amber_rounded;
      statusText = 'Arızalı';
    } else if (isUnderMaintenance) {
      bgColor = AppColors.warningContainer;
      iconColor = AppColors.warningLight;
      iconData = Icons.handyman_outlined;
      statusText = 'Bakımda';
    } else if (elevator.status == 'inactive') {
      bgColor = AppColors.surfaceContainerHigh;
      iconColor = AppColors.onSurfaceVariant;
      iconData = Icons.not_interested_rounded;
      statusText = 'Devre Dışı';
    }

    return Container(
      padding: const EdgeInsets.all(32),
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
          const SizedBox(height: 24),
          Text(
            elevator.buildingName.isNotEmpty
                ? elevator.buildingName
                : 'Asansör',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: iconColor.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: TextStyle(
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
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: AppColors.onError,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
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
      label: const Text(
        'Arıza Bildir',
        style: TextStyle(
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
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
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.build_circle_outlined,
                    color: Color(0xFF4B5563),
                  ),
                ),
                title: Text(
                  dateStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  log.notes != null && log.notes!.isNotEmpty
                      ? log.notes!
                      : 'Periyodik Bakım',
                  style: const TextStyle(color: Colors.black54),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: hasPdf
                    ? IconButton(
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: AppColors.error,
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
      loading: () => const LoadingState(),
      error: (err, _) => ErrorState(
        message: 'Bakım geçmişi alınamadı.\n$err',
        onRetry: onRetry,
      ),
    );
  }
}

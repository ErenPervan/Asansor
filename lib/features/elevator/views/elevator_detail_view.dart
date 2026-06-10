import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/elevator/widgets/detail/elevator_detail_actions.dart';
import 'package:asansor/features/elevator/widgets/detail/elevator_detail_header.dart';
import 'package:asansor/features/elevator/widgets/detail/elevator_maintenance_history.dart';
import 'package:asansor/features/elevator/widgets/detail/elevator_system_monitor.dart';
import 'package:asansor/features/elevator/widgets/detail/log_maintenance_sheet.dart';
import 'package:asansor/features/elevator/widgets/detail/report_fault_sheet.dart';
import 'package:asansor/features/fault/providers/fault_providers.dart';
import 'package:asansor/features/maintenance/providers/maintenance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ElevatorDetailView extends ConsumerWidget {
  const ElevatorDetailView({super.key, required this.elevatorId});

  final String elevatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elevatorAsync = ref.watch(elevatorByIdProvider(elevatorId));
    final colors = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurfaceVariant),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'ElevatePro',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.primaryDark,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: colors.outline),
            tooltip: 'Bildirimler',
            onPressed: () {},
          ),
        ],
      ),
      body: elevatorAsync.when(
        loading: () => const LoadingState(isList: false),
        error: (err, _) {
          final errStr = err.toString();
          if (errStr.contains('PGRST116') ||
              errStr.contains('not found in offline cache') ||
              errStr.contains('Could not find')) {
            return const _ElevatorNotFoundWidget();
          }
          return ErrorState(
            message: errStr.replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(elevatorByIdProvider(elevatorId)),
          );
        },
        data: (elevator) => _DetailScrollBody(
          elevator: elevator,
          elevatorId: elevatorId,
          onReportFault: () {
            ref.invalidate(faultControllerProvider);
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: colors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => ReportFaultSheet(elevatorId: elevatorId),
            );
          },
          onLogMaintenance: () {
            ref.invalidate(maintenanceControllerProvider);
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: colors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => LogMaintenanceSheet(elevatorId: elevatorId),
            );
          },
        ),
      ),
    );
  }
}

class _DetailScrollBody extends StatelessWidget {
  const _DetailScrollBody({
    required this.elevator,
    required this.elevatorId,
    required this.onReportFault,
    required this.onLogMaintenance,
  });

  final ElevatorModel elevator;
  final String elevatorId;
  final VoidCallback onReportFault;
  final VoidCallback onLogMaintenance;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatorDetailHeader(elevator: elevator),
                const SizedBox(height: AppSpacing.lg),
                ElevatorDetailActions(
                  onReportFault: onReportFault,
                  onLogMaintenance: onLogMaintenance,
                ),
                const SizedBox(height: AppSpacing.lg),
                SystemMonitorSection(elevatorId: elevatorId),
                const SizedBox(height: AppSpacing.lg),
                MaintenanceHistorySection(
                  elevatorId: elevatorId,
                  elevator: elevator,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ElevatorNotFoundWidget extends StatelessWidget {
  const _ElevatorNotFoundWidget();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.domain_disabled_rounded,
              size: 80,
              color: colors.outline,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Asansör Bulunamadı',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Bu asansör sistemde kayıtlı değil veya silinmiş.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Ana Sayfaya Dön'),
            ),
          ],
        ),
      ),
    );
  }
}

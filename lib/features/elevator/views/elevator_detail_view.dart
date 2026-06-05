import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/fault/providers/fault_providers.dart';
import 'package:asansor/features/maintenance/providers/maintenance_providers.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/elevator/widgets/detail/elevator_detail_header.dart';
import 'package:asansor/features/elevator/widgets/detail/elevator_detail_actions.dart';
import 'package:asansor/features/elevator/widgets/detail/elevator_system_monitor.dart';
import 'package:asansor/features/elevator/widgets/detail/elevator_maintenance_history.dart';
import 'package:asansor/features/elevator/widgets/detail/report_fault_sheet.dart';
import 'package:asansor/features/elevator/widgets/detail/log_maintenance_sheet.dart';

// ── ElevatorDetailView ────────────────────────────────────────────────────────

class ElevatorDetailView extends ConsumerWidget {
  const ElevatorDetailView({super.key, required this.elevatorId});

  final String elevatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elevatorAsync = ref.watch(elevatorByIdProvider(elevatorId));

    return Scaffold(
      backgroundColor: AppThemeColors.of(context).background,
      // ── Top App Bar ──────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppThemeColors.of(context).background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppThemeColors.of(context).primary,
          ),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Asansör Detayları',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppThemeColors.of(context).onSurface,
          ),
        ),
        centerTitle: false,
      ),

      // ── Body ─────────────────────────────────────────────────────────────
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
              backgroundColor: AppThemeColors.of(context).surface,
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
              backgroundColor: AppThemeColors.of(context).surface,
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

// ── Scrollable body (shown when elevator data is loaded) ─────────────────────

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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1 ── Header identity card ───────────────────────────────────────
          ElevatorDetailHeader(elevator: elevator),
          const SizedBox(height: AppSpacing.lg),

          // 2 ── Quick action buttons ───────────────────────────────────────
          ElevatorDetailActions(
            onReportFault: onReportFault,
            onLogMaintenance: onLogMaintenance,
          ),
          const SizedBox(height: AppSpacing.lg),

          // 3 ── System monitor + next maintenance ─────────────────────────
          SystemMonitorSection(elevatorId: elevatorId),
          const SizedBox(height: AppSpacing.lg),

          // 4 ── Maintenance history timeline ───────────────────────────────
          MaintenanceHistorySection(elevatorId: elevatorId, elevator: elevator),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ── 1. Header Identity Card ───────────────────────────────────────────────────
// Stitch: <section class="bg-surface-container-lowest rounded-xl p-6 shadow-...">

// ── Report Fault Bottom Sheet ─────────────────────────────────────────────────

class _ElevatorNotFoundWidget extends StatelessWidget {
  const _ElevatorNotFoundWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.domain_disabled_rounded,
              size: 80,
              color: AppThemeColors.of(context).outline,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Asansör Bulunamadı',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Bu asansör sistemde kayıtlı değil veya silinmiş.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppThemeColors.of(context).onSurfaceVariant,
              ),
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

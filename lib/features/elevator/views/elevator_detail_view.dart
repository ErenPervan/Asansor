import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../elevator/models/elevator_model.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../../fault/providers/fault_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_state.dart';
import '../widgets/detail/elevator_detail_header.dart';
import '../widgets/detail/elevator_detail_actions.dart';
import '../widgets/detail/elevator_system_monitor.dart';
import '../widgets/detail/elevator_maintenance_history.dart';
import '../widgets/detail/report_fault_sheet.dart';
import '../widgets/detail/log_maintenance_sheet.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';

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
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Asansör Detayları',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppColors.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: elevatorAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16.0),
          child: LoadingState(isList: false),
        ),
        error: (err, _) => _ErrorBody(
          message: err.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(elevatorByIdProvider(elevatorId)),
        ),
        data: (elevator) => _DetailScrollBody(
          elevator: elevator,
          elevatorId: elevatorId,
          onReportFault: () {
            ref.invalidate(faultControllerProvider);
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
          onLogMaintenance: () {
            ref.invalidate(maintenanceControllerProvider);
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => LogMaintenanceSheet(elevatorId: elevatorId),
            );
          },
        ),
      ),

      // ── Bottom Navigation ─────────────────────────────────────────────────
      bottomNavigationBar: const AppBottomNavBar(currentIndex: -1),
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
          const SizedBox(height: 24),

          // 2 ── Quick action buttons ───────────────────────────────────────
          ElevatorDetailActions(
            onReportFault: onReportFault,
            onLogMaintenance: onLogMaintenance,
          ),
          const SizedBox(height: 24),

          // 3 ── System monitor + next maintenance ─────────────────────────
          SystemMonitorSection(elevatorId: elevatorId),
          const SizedBox(height: 24),

          // 4 ── Maintenance history timeline ───────────────────────────────
          MaintenanceHistorySection(elevatorId: elevatorId, elevator: elevator),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── 1. Header Identity Card ───────────────────────────────────────────────────
// Stitch: <section class="bg-surface-container-lowest rounded-xl p-6 shadow-...">

// ── Report Fault Bottom Sheet ─────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

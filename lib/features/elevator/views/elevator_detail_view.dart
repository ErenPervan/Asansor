import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../elevator/models/elevator_model.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../../fault/providers/fault_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_async_view.dart';
import '../widgets/detail/elevator_detail_header.dart';
import '../widgets/detail/elevator_detail_actions.dart';
import '../widgets/detail/elevator_system_monitor.dart';
import '../widgets/detail/elevator_maintenance_history.dart';
import '../widgets/detail/report_fault_sheet.dart';
import '../widgets/detail/log_maintenance_sheet.dart';

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
      body: AppAsyncView<ElevatorModel>(
        value: elevatorAsync,
        onRetry: () => ref.invalidate(elevatorByIdProvider(elevatorId)),
        isList: false,
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sync_queue_service.dart';
import '../models/maintenance_log_model.dart';
import '../repositories/maintenance_repository.dart';
import '../../admin/repositories/schedule_repository.dart';

// ── Repository ──────────────────────────────────────────────────────────────

/// Provides the [MaintenanceRepository] backed by the live Supabase client.
final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository(Supabase.instance.client);
});

// ── Data Providers ───────────────────────────────────────────────────────────

/// Fetches all pending (unapproved) maintenance logs across every elevator.
///
/// Used by the dashboard to populate the "Günlük Bakımlar" section.
final pendingMaintenanceProvider =
    FutureProvider<List<MaintenanceLogModel>>((ref) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return repo.getAllPendingLogs();
});

/// Returns the count of maintenance logs completed (approved) today.
final completedTodayCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return repo.getCompletedTodayCount();
});

/// Fetches all maintenance logs for a given elevator [id].
///
/// Usage: `ref.watch(logsByElevatorProvider('some-uuid'))`
final logsByElevatorProvider =
    FutureProvider.family<List<MaintenanceLogModel>, String>(
        (ref, elevatorId) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return repo.getLogsByElevatorId(elevatorId);
});

// ── Action Notifier ──────────────────────────────────────────────────────────

/// Holds the state of an in-flight maintenance log submission.
///
/// Call [MaintenanceController.addLog] to submit.
class MaintenanceController extends AsyncNotifier<MaintenanceLogModel?> {
  @override
  Future<MaintenanceLogModel?> build() async => null;

  Future<void> addLog({
    required String elevatorId,
    required String technicianId,
    required String notes,
    required DateTime maintenanceDate,
  }) async {
    state = const AsyncLoading();

    final isOnline = ref.read(isOnlineProvider);

    if (!isOnline) {
      // ── Offline path: enqueue for later sync ──────────────────────────────
      await ref.read(syncQueueServiceProvider).enqueue(
        type: SyncItemType.maintenanceLog,
        payload: {
          'elevator_id': elevatorId,
          'technician_id': technicianId,
          'notes': notes,
          'is_approved': false,
          'maintenance_date': maintenanceDate.toIso8601String(),
        },
      );

      // Represent success with a synthetic in-memory model so the UI can
      // show a "saved offline" confirmation without a null-state guard.
      state = AsyncData(
        MaintenanceLogModel(
          id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
          elevatorId: elevatorId,
          technicianId: technicianId,
          notes: notes,
          isApproved: false,
          maintenanceDate: maintenanceDate,
          isOfflineQueued: true,
        ),
      );
      return;
    }

    // ── Online path: write directly to Supabase ───────────────────────────
    state = await AsyncValue.guard(() {
      return ref.read(maintenanceRepositoryProvider).addLog(
            elevatorId: elevatorId,
            technicianId: technicianId,
            notes: notes,
            maintenanceDate: maintenanceDate,
          );
    });

    // After a successful log, auto-complete any matching scheduled task
    // for the same elevator+technician on today's date.
    if (!state.hasError && state.value != null) {
      await ScheduleRepository(Supabase.instance.client)
          .completeMatchingSchedule(
        elevatorId: elevatorId,
        technicianId: technicianId,
      );

      // Notify all admins that a maintenance job has been completed.
      NotificationService.instance.notifyAllAdmins(
        client: Supabase.instance.client,
        title: 'Bakım Tamamlandı',
        body: 'Bir teknisyen bakım görevini tamamladı.',
        data: {
          'type': 'task_completed',
          'route': '/admin/master-calendar',
          'elevator_id': elevatorId,
        },
      );
    }
  }
}

final maintenanceControllerProvider =
    AsyncNotifierProvider<MaintenanceController, MaintenanceLogModel?>(
  MaintenanceController.new,
);

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asansor/core/services/read_cache_service.dart';
import 'package:asansor/core/services/sync/sync_coordinator.dart';
import 'package:asansor/core/services/sync/sync_remote_writer.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import 'package:asansor/features/admin/models/schedule_model.dart';
import 'package:asansor/features/admin/models/checklist_item_model.dart';

// ── ProviderContainer helper ──────────────────────────────────────────────────

/// Creates a [ProviderContainer] and automatically disposes it at the end of
/// a test.
ProviderContainer createContainer({
  ProviderContainer? parent,
  List<Override> overrides = const [],
  List<ProviderObserver>? observers,
}) {
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
    observers: observers,
  );
  addTearDown(container.dispose);
  return container;
}

// ── FakeReadCacheService ──────────────────────────────────────────────────────

/// A no-op implementation of [ReadCacheService] that returns empty / zero
/// values without requiring Hive boxes to be opened.
///
/// Use this in unit / provider tests via:
/// ```dart
/// readCacheServiceProvider.overrideWithValue(fakeCache)
/// ```
class FakeReadCacheService implements ReadCacheService {
  // ── Modifiable state for tests ──────────────────────────────────────────────
  List<ElevatorModel> elevators = [];
  List<FaultReportModel> allFaults = [];
  List<FaultReportModel> activeFaults = [];
  List<MaintenanceLogModel> pendingLogs = [];

  // ── Elevators ───────────────────────────────────────────────────────────────
  @override
  bool get hasElevators => elevators.isNotEmpty;
  @override
  List<ElevatorModel> loadElevators() => elevators;
  @override
  Future<void> saveElevators(List<ElevatorModel> elevators) async {
    this.elevators = elevators;
  }

  // ── Tasks ───────────────────────────────────────────────────────────────────
  @override
  bool hasMyTasks(String userId) => false;
  @override
  List<ScheduleModel> loadMyTasks(String userId) => [];
  @override
  Future<void> saveMyTasks(String userId, List<ScheduleModel> tasks) async {}

  // ── Checklists ──────────────────────────────────────────────────────────────
  @override
  List<ChecklistItemModel> loadChecklistItems() => [];
  @override
  Future<void> saveChecklistItems(List<ChecklistItemModel> items) async {}

  // ── Past Logs ───────────────────────────────────────────────────────────────
  @override
  List<MaintenanceLogModel> loadPastLogs(String elevatorId) => [];
  @override
  Future<void> savePastLogs(
    String elevatorId,
    List<MaintenanceLogModel> logs,
  ) async {}

  // ── Faults ──────────────────────────────────────────────────────────────────
  @override
  List<FaultReportModel> loadActiveFaults() => activeFaults;
  @override
  Future<void> saveActiveFaults(List<FaultReportModel> faults) async {
    activeFaults = faults;
  }

  @override
  List<FaultReportModel> loadAllFaults() => allFaults;
  @override
  Future<void> saveAllFaults(List<FaultReportModel> faults) async {
    allFaults = faults;
  }

  @override
  List<FaultReportModel> loadFaultsByElevatorId(String elevatorId) {
    return allFaults.where((f) => f.elevatorId == elevatorId).toList();
  }

  @override
  FaultReportModel? loadFaultById(String faultId) {
    return allFaults.where((f) => f.id == faultId).firstOrNull;
  }

  // ── Pending Maintenance ─────────────────────────────────────────────────────
  @override
  List<MaintenanceLogModel> loadPendingMaintenance() => pendingLogs;
  @override
  Future<void> savePendingMaintenance(List<MaintenanceLogModel> logs) async {
    pendingLogs = logs;
  }

  // ── Completed Today Count ───────────────────────────────────────────────────
  @override
  int loadCompletedTodayCount() => 0;
  @override
  Future<void> saveCompletedTodayCount(int count) async {}

  // ── Cache Cleanup ───────────────────────────────────────────────────────────
  @override
  Future<void> clearAll() async {
    elevators.clear();
    allFaults.clear();
    activeFaults.clear();
    pendingLogs.clear();
  }
}

// ── FakeSyncQueueService ──────────────────────────────────────────────────────

/// A no-op implementation of [SyncQueueService] that returns empty / zero
/// values without requiring Hive boxes to be opened.
class FakeSyncQueueService extends ChangeNotifier implements SyncQueueService {
  @override
  set overrideRemoteWriter(SyncRemoteWriter writer) {}

  @override
  int get pendingCount => 0;

  @override
  int get conflictCount => 0;

  @override
  int get failedCount => 0;

  @override
  bool get hasPending => false;

  @override
  List<Map<String, dynamic>> get conflictedItems => [];

  @override
  List<Map<String, dynamic>> get pendingItems => [];

  @override
  Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload,
  }) async {}

  @override
  Future<SyncResult> flush(SupabaseClient client) async {
    return const SyncResult(synced: 0, failed: 0);
  }

  @override
  Future<void> resolveForceUpdate(SupabaseClient client, String key) async {}

  @override
  Future<void> resolveFlagDisputed(SupabaseClient client, String key) async {}

  @override
  Future<void> resolveDiscard(SupabaseClient client, String key) async {}
}

// ── SpySyncQueueService ───────────────────────────────────────────────────────

/// A spy implementation of [SyncQueueService] that records calls to `enqueue`
/// and `flush`. Useful for testing controller write paths.
class SpySyncQueueService extends FakeSyncQueueService {
  final List<Map<String, dynamic>> enqueuedItems = [];
  int flushCallCount = 0;
  bool shouldThrowOnFlush = false;

  @override
  Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    enqueuedItems.add({'type': type, 'payload': payload});
  }

  @override
  Future<SyncResult> flush(SupabaseClient client) async {
    flushCallCount++;
    if (shouldThrowOnFlush) {
      throw Exception('Mock flush error');
    }
    return const SyncResult(synced: 1, failed: 0);
  }
}

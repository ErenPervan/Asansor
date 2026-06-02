import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asansor/core/services/read_cache_service.dart';
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
  // ── Elevators ───────────────────────────────────────────────────────────────
  @override
  bool get hasElevators => false;
  @override
  List<ElevatorModel> loadElevators() => [];
  @override
  Future<void> saveElevators(List<ElevatorModel> elevators) async {}

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
  List<FaultReportModel> loadActiveFaults() => [];
  @override
  Future<void> saveActiveFaults(List<FaultReportModel> faults) async {}
  @override
  List<FaultReportModel> loadAllFaults() => [];
  @override
  Future<void> saveAllFaults(List<FaultReportModel> faults) async {}

  // ── Pending Maintenance ─────────────────────────────────────────────────────
  @override
  List<MaintenanceLogModel> loadPendingMaintenance() => [];
  @override
  Future<void> savePendingMaintenance(List<MaintenanceLogModel> logs) async {}

  // ── Completed Today Count ───────────────────────────────────────────────────
  @override
  int loadCompletedTodayCount() => 0;
  @override
  Future<void> saveCompletedTodayCount(int count) async {}
}

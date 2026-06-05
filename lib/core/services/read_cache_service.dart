import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../features/admin/models/schedule_model.dart';
import '../../features/admin/models/checklist_item_model.dart';
import '../../features/elevator/models/elevator_model.dart';
import '../../features/fault/models/fault_report_model.dart';
import '../../features/maintenance/models/maintenance_log_model.dart';

// ── Box names ─────────────────────────────────────────────────────────────────

/// Name of the Hive box used to cache the full elevator list.
const elevatorsCacheBoxName = 'elevators_cache';

/// Name of the Hive box used to cache per-user task lists.
const tasksCacheBoxName = 'tasks_cache';

/// Name of the Hive box used to cache checklist items.
const checklistCacheBoxName = 'checklist_cache';

/// Name of the Hive box used to cache past maintenance logs.
const pastLogsCacheBoxName = 'past_logs_cache';

/// Name of the Hive box used to cache active faults.
const faultsCacheBoxName = 'faults_cache';

// ── Service ───────────────────────────────────────────────────────────────────

/// Provides a thin read/write cache layer backed by Hive.
///
/// Data is serialised to JSON strings so no Hive type-adapters are required.
///
/// Boxes must be opened before constructing this service (typically in
/// `main.dart`):
/// ```dart
/// await Hive.openBox<String>(elevatorsCacheBoxName);
/// await Hive.openBox<String>(tasksCacheBoxName);
/// await Hive.openBox<String>(checklistCacheBoxName);
/// await Hive.openBox<String>(pastLogsCacheBoxName);
/// ```
class ReadCacheService {
  static const _elevatorsKey = 'all';
  static const _checklistsKey = 'all_checklists';

  Box<String> get _elevBox => Hive.box<String>(elevatorsCacheBoxName);
  Box<String> get _tasksBox => Hive.box<String>(tasksCacheBoxName);
  Box<String> get _checklistBox => Hive.box<String>(checklistCacheBoxName);
  Box<String> get _pastLogsBox => Hive.box<String>(pastLogsCacheBoxName);
  Box<String> get _faultsBox => Hive.box<String>(faultsCacheBoxName);

  // ── Elevators ─────────────────────────────────────────────────────────────

  /// Persists [elevators] as a JSON string.  Overwrites any previous value.
  Future<void> saveElevators(List<ElevatorModel> elevators) async {
    final encoded = jsonEncode(elevators.map((e) => e.toJson()).toList());
    await _elevBox.put(_elevatorsKey, encoded);
  }

  /// Returns the cached elevator list, or an empty list if nothing is cached
  /// or the stored data cannot be decoded.
  List<ElevatorModel> loadElevators() {
    final raw = _elevBox.get(_elevatorsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => ElevatorModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// `true` when at least one elevator has been stored in the cache.
  bool get hasElevators => _elevBox.containsKey(_elevatorsKey);

  // ── Tasks (per user) ──────────────────────────────────────────────────────

  /// Persists the task list for [userId].  Overwrites any previous value.
  ///
  /// Each [ScheduleModel] is serialised with its own `toJson()`.
  Future<void> saveMyTasks(String userId, List<ScheduleModel> tasks) async {
    if (userId.isEmpty) return;
    final encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await _tasksBox.put(userId, encoded);
  }

  /// Returns the cached task list for [userId], or an empty list if nothing
  /// is cached or the stored data cannot be decoded.
  List<ScheduleModel> loadMyTasks(String userId) {
    if (userId.isEmpty) return [];
    final raw = _tasksBox.get(userId);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => ScheduleModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// `true` when a task list has been cached for [userId].
  bool hasMyTasks(String userId) =>
      userId.isNotEmpty && _tasksBox.containsKey(userId);

  // ── Checklists ────────────────────────────────────────────────────────────

  /// Persists the checklist items. Overwrites any previous value.
  Future<void> saveChecklistItems(List<ChecklistItemModel> items) async {
    final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
    await _checklistBox.put(_checklistsKey, encoded);
  }

  /// Returns the cached checklist items.
  List<ChecklistItemModel> loadChecklistItems() {
    final raw = _checklistBox.get(_checklistsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => ChecklistItemModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Past Logs ─────────────────────────────────────────────────────────────

  /// Persists the past logs for [elevatorId]. Overwrites any previous value.
  Future<void> savePastLogs(
    String elevatorId,
    List<MaintenanceLogModel> logs,
  ) async {
    if (elevatorId.isEmpty) return;
    final encoded = jsonEncode(logs.map((l) => l.toJson()).toList());
    await _pastLogsBox.put(elevatorId, encoded);
  }

  /// Returns the cached past logs for [elevatorId].
  List<MaintenanceLogModel> loadPastLogs(String elevatorId) {
    if (elevatorId.isEmpty) return [];
    final raw = _pastLogsBox.get(elevatorId);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => MaintenanceLogModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Faults ─────────────────────────────────────────────────────────────

  /// Persists active faults. Overwrites any previous value.
  Future<void> saveActiveFaults(List<FaultReportModel> faults) async {
    final encoded = jsonEncode(faults.map((f) => f.toJson()).toList());
    await _faultsBox.put('active_faults', encoded);
  }

  /// Returns the cached active faults.
  List<FaultReportModel> loadActiveFaults() {
    final raw = _faultsBox.get('active_faults');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => FaultReportModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persists all faults. Overwrites any previous value.
  Future<void> saveAllFaults(List<FaultReportModel> faults) async {
    final encoded = jsonEncode(faults.map((f) => f.toJson()).toList());
    await _faultsBox.put('all_faults', encoded);
  }

  /// Returns all cached faults.
  List<FaultReportModel> loadAllFaults() {
    final raw = _faultsBox.get('all_faults');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => FaultReportModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Pending Maintenance Logs ────────────────────────────────────────────────

  /// Persists pending maintenance logs. Overwrites any previous value.
  Future<void> savePendingMaintenance(List<MaintenanceLogModel> logs) async {
    final encoded = jsonEncode(logs.map((l) => l.toJson()).toList());
    await _pastLogsBox.put('pending_logs', encoded);
  }

  /// Returns the cached pending maintenance logs, or an empty list if nothing is cached.
  List<MaintenanceLogModel> loadPendingMaintenance() {
    final raw = _pastLogsBox.get('pending_logs');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => MaintenanceLogModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Completed Today Count ───────────────────────────────────────────────────

  /// Persists the completed today count. Overwrites any previous value.
  Future<void> saveCompletedTodayCount(int count) async {
    await _pastLogsBox.put('completed_today_count', count.toString());
  }

  /// Returns the cached completed today count, or 0 if nothing is cached.
  int loadCompletedTodayCount() {
    final raw = _pastLogsBox.get('completed_today_count');
    if (raw == null) return 0;
    return int.tryParse(raw) ?? 0;
  }

  // ── Cache Cleanup ───────────────────────────────────────────────────────────

  /// Tüm read-only önbellek kutularını temizler.
  /// Sign-out sonrasında [RouterNotifier._clearUserData()] tarafından çağrılır.
  /// Sync queue intentionally excluded — see [SyncQueueService].
  Future<void> clearAll() async {
    await _elevBox.clear();
    await _tasksBox.clear();
    await _checklistBox.clear();
    await _pastLogsBox.clear();
    await _faultsBox.clear();
  }
}

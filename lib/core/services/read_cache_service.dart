import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../features/admin/models/schedule_model.dart';
import '../../features/elevator/models/elevator_model.dart';

// ── Box names ─────────────────────────────────────────────────────────────────

/// Name of the Hive box used to cache the full elevator list.
const elevatorsCacheBoxName = 'elevators_cache';

/// Name of the Hive box used to cache per-user task lists.
const tasksCacheBoxName = 'tasks_cache';

/// Name of the Hive box used to cache checklist items.
const checklistCacheBoxName = 'checklist_cache';

/// Name of the Hive box used to cache past maintenance logs.
const pastLogsCacheBoxName = 'past_logs_cache';

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

  // ── Elevators ─────────────────────────────────────────────────────────────

  /// Persists [elevators] as a JSON string.  Overwrites any previous value.
  Future<void> saveElevators(List<ElevatorModel> elevators) async {
    final encoded = jsonEncode(
      elevators.map((e) => e.toJson()).toList(),
    );
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
    final encoded = jsonEncode(
      tasks.map((t) => t.toJson()).toList(),
    );
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
  Future<void> saveChecklistItems(List<dynamic> items) async {
    final encoded = jsonEncode(
      items.map((i) => i.toJson()).toList(),
    );
    await _checklistBox.put(_checklistsKey, encoded);
  }

  /// Returns the cached checklist items.
  List<dynamic> loadChecklistItems(dynamic fromJson) {
    final raw = _checklistBox.get(_checklistsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((j) => fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Past Logs ─────────────────────────────────────────────────────────────

  /// Persists the past logs for [elevatorId]. Overwrites any previous value.
  Future<void> savePastLogs(String elevatorId, List<dynamic> logs) async {
    if (elevatorId.isEmpty) return;
    final encoded = jsonEncode(
      logs.map((l) => l.toJson()).toList(),
    );
    await _pastLogsBox.put(elevatorId, encoded);
  }

  /// Returns the cached past logs for [elevatorId].
  List<dynamic> loadPastLogs(String elevatorId, dynamic fromJson) {
    if (elevatorId.isEmpty) return [];
    final raw = _pastLogsBox.get(elevatorId);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((j) => fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}

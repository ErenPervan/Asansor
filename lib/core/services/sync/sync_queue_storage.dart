import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

const syncQueueBoxName = 'pending_sync';

const statusPending = 'pending';
const statusPdfPending = 'pdf_pending';
const statusSchedulePending = 'schedule_pending';
const statusConflictDetected = 'conflict_detected';
const statusResolving = 'resolving';
const statusDeadLetter = 'dead_letter';

abstract final class SyncItemType {
  static const maintenanceLog = 'maintenance_log';
  static const faultReport = 'fault_report';
  static const elevatorUpdate = 'elevator_update';
  static const faultResolve = 'fault_resolve';
  static const faultReopen = 'fault_reopen';
}

class SyncQueueStorage extends ChangeNotifier {
  static const _uuid = Uuid();

  Box<String> get _box => Hive.box<String>(syncQueueBoxName);

  int get pendingCount => _box.values.where((raw) {
    try {
      final item = jsonDecode(raw) as Map<String, dynamic>;
      final status = item['status'];
      return status != statusConflictDetected && status != statusDeadLetter;
    } catch (_) {
      return true;
    }
  }).length;

  int get conflictCount => _box.values.where((raw) {
    try {
      final item = jsonDecode(raw) as Map<String, dynamic>;
      return item['status'] == statusConflictDetected ||
          item['status'] == statusResolving;
    } catch (_) {
      return false;
    }
  }).length;

  int get failedCount => _box.values.where((raw) {
    try {
      final item = jsonDecode(raw) as Map<String, dynamic>;
      return item['status'] == statusDeadLetter;
    } catch (_) {
      return false;
    }
  }).length;

  bool get hasPending => pendingCount > 0;

  List<Map<String, dynamic>> get conflictedItems {
    return _box.keys
        .map((key) {
          final raw = _box.get(key);
          if (raw == null) return null;
          try {
            final item = jsonDecode(raw) as Map<String, dynamic>;
            if (item['status'] == statusConflictDetected ||
                item['status'] == statusResolving) {
              return {'key': key, ...item};
            }
          } catch (_) {}
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  List<Map<String, dynamic>> get pendingItems {
    return _box.keys
        .map((key) {
          final raw = _box.get(key);
          if (raw == null) return null;
          try {
            final item = jsonDecode(raw) as Map<String, dynamic>;
            if (item['status'] == statusPending ||
                item['status'] == statusDeadLetter) {
              return {'key': key, ...item};
            }
          } catch (_) {}
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final id = _uuid.v4();
    final item = jsonEncode({
      'id': id,
      'type': type,
      'payload': payload,
      'queued_at': DateTime.now().toIso8601String(),
      'status': statusPending,
      'retry_count': 0,
      'next_retry_at': null,
    });
    await _box.put(id, item);
    notifyListeners();
  }

  List<String> get keys => _box.keys.cast<String>().toList()..sort();

  String? get(String key) => _box.get(key);

  Future<void> put(String key, String value) => _box.put(key, value);

  Future<void> delete(String key) => _box.delete(key);

  void triggerNotify() {
    notifyListeners();
  }
}

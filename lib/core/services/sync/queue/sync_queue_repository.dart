import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:asansor/core/services/sync/queue/sync_item.dart';

class SyncQueueRepository {
  static const _uuid = Uuid();

  Box<String> get _box => Hive.box<String>(syncQueueBoxName);

  List<String> get keys => _box.keys.cast<String>().toList()..sort();

  String? get(String key) => _box.get(key);

  Future<void> put(String key, String item) => _box.put(key, item);

  Future<void> delete(String key) => _box.delete(key);

  int get pendingCount => _box.values.where((raw) {
    try {
      final item = jsonDecode(raw) as Map<String, dynamic>;
      final status = item['status'];
      return status != syncStatusConflictDetected && status != syncStatusDeadLetter;
    } catch (_) {
      return true;
    }
  }).length;

  int get conflictCount => _box.values.where((raw) {
    try {
      final item = jsonDecode(raw) as Map<String, dynamic>;
      return item['status'] == syncStatusConflictDetected;
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
            if (item['status'] == syncStatusConflictDetected) {
              return {'key': key, ...item};
            }
          } catch (_) {}
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  int get deadLetterCount => _box.values.where((raw) {
    try {
      final item = jsonDecode(raw) as Map<String, dynamic>;
      return item['status'] == syncStatusDeadLetter;
    } catch (_) {
      return false;
    }
  }).length;

  List<Map<String, dynamic>> get failedItems {
    return _box.keys
        .map((key) {
          final raw = _box.get(key);
          if (raw == null) return null;
          try {
            final item = jsonDecode(raw) as Map<String, dynamic>;
            if (item['status'] == syncStatusConflictDetected ||
                item['status'] == syncStatusDeadLetter) {
              return {'key': key, ...item};
            }
          } catch (_) {}
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  List<Map<String, dynamic>> pendingItemsOfType(String type) {
    return _box.values
        .map((raw) {
          try {
            return jsonDecode(raw) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .where((item) =>
            item['type'] == type &&
            (item['status'] == syncStatusPending ||
             item['status'] == syncStatusResolving))
        .map((item) => item['payload'] as Map<String, dynamic>)
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
      'status': syncStatusPending,
    });
    await _box.put(id, item);
  }
}

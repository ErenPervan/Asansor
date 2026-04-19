import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// The name of the Hive box that holds unsynced operations.
const syncQueueBoxName = 'pending_sync';

/// Supported operation types that can be queued.
abstract final class SyncItemType {
  static const maintenanceLog = 'maintenance_log';
  static const faultReport = 'fault_report';
}

// ─────────────────────────────────────────────────────────────────────────────
// Result
// ─────────────────────────────────────────────────────────────────────────────

/// Returned by [SyncQueueService.flush] describing how the sync went.
class SyncResult {
  const SyncResult({required this.synced, required this.failed});

  final int synced;
  final int failed;

  bool get hasFailures => failed > 0;

  @override
  String toString() => 'SyncResult(synced: $synced, failed: $failed)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

/// Manages a local Hive queue of Supabase write operations that could not be
/// executed while the device was offline.
///
/// Usage:
/// ```dart
/// // Enqueue an item (offline write)
/// await service.enqueue(type: SyncItemType.maintenanceLog, payload: {...});
///
/// // Flush on reconnect
/// final result = await service.flush(Supabase.instance.client);
/// ```
///
/// Extends [ChangeNotifier] so Riverpod `ChangeNotifierProvider` watchers
/// (e.g. `pendingSyncCountProvider`) rebuild automatically when the queue
/// changes.
class SyncQueueService extends ChangeNotifier {
  SyncQueueService();

  Box<String> get _box => Hive.box<String>(syncQueueBoxName);

  /// Number of items currently waiting to be synced.
  int get pendingCount => _box.length;

  /// Whether there are items waiting in the queue.
  bool get hasPending => pendingCount > 0;

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Saves [payload] as a pending operation of the given [type].
  ///
  /// [type] must be one of the [SyncItemType] constants.
  /// Include an `elevator_id` key in [payload] when the type is
  /// `maintenance_log` so the flush step can complete matching schedules.
  Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final id =
        DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final item = jsonEncode({
      'id': id,
      'type': type,
      'payload': payload,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _box.put(id, item);
    notifyListeners();
  }

  // ── Flush ─────────────────────────────────────────────────────────────────

  /// Processes every queued item in chronological order.
  ///
  /// Items that succeed are removed from the box.
  /// Items that fail are kept for the next attempt.
  Future<SyncResult> flush(SupabaseClient client) async {
    // Sort keys so we replay in the order they were queued.
    final keys = _box.keys.cast<String>().toList()..sort();

    int synced = 0;
    int failed = 0;

    for (final key in keys) {
      final raw = _box.get(key);
      if (raw == null) continue;

      try {
        final item = jsonDecode(raw) as Map<String, dynamic>;
        await _process(client, item);
        await _box.delete(key);
        synced++;
      } catch (_) {
        // Keep in the queue; will retry next time we're online.
        failed++;
      }
    }

    if (synced > 0 || failed == 0) {
      notifyListeners();
    }

    return SyncResult(synced: synced, failed: failed);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _process(
      SupabaseClient client, Map<String, dynamic> item) async {
    final type = item['type'] as String;
    final payload =
        Map<String, dynamic>.from(item['payload'] as Map);

    switch (type) {
      case SyncItemType.maintenanceLog:
        await _syncMaintenanceLog(client, payload);
        break;
      case SyncItemType.faultReport:
        await _syncFaultReport(client, payload);
        break;
      default:
        throw UnsupportedError('Unknown sync type: $type');
    }
  }

  Future<void> _syncMaintenanceLog(
      SupabaseClient client, Map<String, dynamic> payload) async {
    // Strip internal metadata before inserting.
    final elevatorId = payload['elevator_id'] as String?;
    final technicianId = payload['technician_id'] as String?;

    final row = Map<String, dynamic>.from(payload)
      ..remove('_complete_schedule');

    await client.from('maintenance_logs').insert(row);

    // After a successful log, complete any matching pending schedule.
    if (elevatorId != null && technicianId != null) {
      try {
        final today = DateTime.now();
        final start =
            DateTime(today.year, today.month, today.day).toIso8601String();
        final end = DateTime(today.year, today.month, today.day, 23, 59, 59)
            .toIso8601String();

        await client
            .from('maintenance_schedules')
            .update({'status': 'completed'})
            .eq('elevator_id', elevatorId)
            .eq('technician_id', technicianId)
            .inFilter('status', ['pending', 'in_progress'])
            .gte('scheduled_date', start)
            .lte('scheduled_date', end);
      } catch (_) {
        // Schedule completion is best-effort; don't fail the whole sync.
      }
    }
  }

  Future<void> _syncFaultReport(
      SupabaseClient client, Map<String, dynamic> payload) async {
    await client.from('fault_reports').insert(payload);
  }
}

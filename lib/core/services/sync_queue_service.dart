import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/maintenance/models/maintenance_log_model.dart';
import '../exceptions/conflict_exception.dart';
import 'pdf_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// The name of the Hive box that holds unsynced operations.
const syncQueueBoxName = 'pending_sync';

/// Supported operation types that can be queued.
abstract final class SyncItemType {
  static const maintenanceLog = 'maintenance_log';
  static const faultReport = 'fault_report';
  static const elevatorUpdate = 'elevator_update';
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
  int get pendingCount => _box.values.where((raw) {
        try {
          final item = jsonDecode(raw) as Map<String, dynamic>;
          return item['status'] != 'conflict_detected';
        } catch (_) {
          return true;
        }
      }).length;

  /// Number of items with conflicts.
  int get conflictCount => _box.values.where((raw) {
        try {
          final item = jsonDecode(raw) as Map<String, dynamic>;
          return item['status'] == 'conflict_detected';
        } catch (_) {
          return false;
        }
      }).length;

  /// Whether there are items waiting in the queue.
  bool get hasPending => pendingCount > 0;

  /// Get conflicted items
  List<Map<String, dynamic>> get conflictedItems {
    return _box.keys.map((key) {
      final raw = _box.get(key);
      if (raw == null) return null;
      try {
        final item = jsonDecode(raw) as Map<String, dynamic>;
        if (item['status'] == 'conflict_detected') {
          return {'key': key, ...item};
        }
      } catch (_) {}
      return null;
    }).whereType<Map<String, dynamic>>().toList();
  }

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
      'status': 'pending',
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
        
        if (item['status'] == 'conflict_detected') {
          failed++;
          continue; // Skip conflicted items, they require manual resolution
        }

        await _process(client, item);
        await _box.delete(key);
        synced++;
      } on ConflictException catch (e) {
        final item = jsonDecode(raw) as Map<String, dynamic>;
        item['status'] = 'conflict_detected';
        item['remote_state'] = e.remoteState;
        await _box.put(key, jsonEncode(item));
        failed++;
      } catch (e, s) {
        debugPrint('[SyncQueue] Unexpected error in flush: $e\n$s');
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
      case SyncItemType.elevatorUpdate:
        await _syncElevatorUpdate(client, payload);
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

    final response = await client.from('maintenance_logs').insert(row).select().maybeSingle();

    if (response != null) {
      try {
        // ── Step 1: Generate the PDF ──────────────────────────────────────────
        final logModel = MaintenanceLogModel.fromJson(response);
        final pdfFile = await PdfService().generateMaintenanceReport(
          log: logModel,
          checklistDetails: [], // Checklist mapping verified: currently not in schema, placeholder used
        );

        // ── Step 2: Upload to Supabase Storage ───────────────────────────────
        final fileName =
            'report_${logModel.elevatorId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        await client.storage.from('maintenance-reports').upload(fileName, pdfFile);

        // ── Step 3: Write the public URL back to maintenance_logs.pdf_url ────
        final publicUrl =
            client.storage.from('maintenance-reports').getPublicUrl(fileName);
        await client
            .from('maintenance_logs')
            .update({'pdf_url': publicUrl})
            .eq('id', logModel.id);
        debugPrint('[SyncQueue] PDF uploaded & linked: $publicUrl');

        // ── Step 4: Notify the customer who owns this elevator ───────────────
        try {
          final customerData = await client
              .from('profiles')
              .select('id')
              .eq('elevator_id', logModel.elevatorId)
              .eq('role', 'customer')
              .maybeSingle();

          if (customerData != null) {
            final customerId = customerData['id'] as String;
            await client.functions.invoke(
              'send-notification',
              body: {
                'to_user_id': customerId,
                'title': 'Bakım Tamamlandı ✓',
                'body':
                    'Asansörünüzün periyodik bakımı tamamlandı. Rapora göz atabilirsiniz.',
                'data': {
                  'route': '/customer',
                  'pdf_url': publicUrl,
                },
              },
            );
            debugPrint('[SyncQueue] Customer notification sent to: $customerId');
          } else {
            debugPrint(
                '[SyncQueue] No customer profile found for elevator ${logModel.elevatorId}. Skipping notification.');
          }
        } catch (notifErr) {
          // Notification failure must never crash the sync — log and continue.
          debugPrint('[SyncQueue] Customer notification failed (non-fatal): $notifErr');
        }
      } catch (e) {
        debugPrint('[SyncQueue] Failed to generate or upload PDF report: $e');
      }

    }

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

  Future<void> _syncElevatorUpdate(
      SupabaseClient client, Map<String, dynamic> payload) async {
    final id = payload['id'] as String;
    final baseVersion = payload['base_version'] as int;
    final changes = Map<String, dynamic>.from(payload)
      ..remove('id')
      ..remove('base_version');

    final response = await client
        .from('elevators')
        .update(changes)
        .eq('id', id)
        .eq('version', baseVersion)
        .select()
        .maybeSingle();

    if (response == null) {
      // Version mismatch or deleted
      final remote = await client.from('elevators').select().eq('id', id).maybeSingle();
      if (remote != null) {
        throw ConflictException(remoteState: remote);
      } else {
        throw Exception('Elevator not found for update.');
      }
    }
  }

  // ── Conflict Resolution ───────────────────────────────────────────────────

  /// Forces the local changes to be applied by fetching the latest remote version
  /// and applying the update with that version, discarding the remote changes.
  Future<void> resolveForceUpdate(SupabaseClient client, String key) async {
    final raw = _box.get(key);
    if (raw == null) return;
    
    final item = jsonDecode(raw) as Map<String, dynamic>;
    final payload = item['payload'] as Map<String, dynamic>;
    final id = payload['id'] as String;

    final remote = await client.from('elevators').select('version').eq('id', id).maybeSingle();
    if (remote != null) {
      payload['base_version'] = remote['version'];
      item['status'] = 'pending';
      item.remove('remote_state');
      await _box.put(key, jsonEncode(item));
      
      // Try to flush this item specifically
      await flush(client);
    }
  }

  /// Escalates the conflict to the admin by inserting a record into `conflict_reports`
  /// and removing the item from the local queue.
  Future<void> resolveFlagDisputed(SupabaseClient client, String key) async {
    final raw = _box.get(key);
    if (raw == null) return;

    final item = jsonDecode(raw) as Map<String, dynamic>;
    final payload = item['payload'] as Map<String, dynamic>;
    final id = payload['id'] as String;
    final remoteState = item['remote_state'] as Map<String, dynamic>;

    await client.from('conflict_reports').insert({
      'elevator_id': id,
      'technician_id': client.auth.currentUser!.id,
      'local_payload': payload,
      'remote_payload': remoteState,
      'status': 'pending',
    });

    await _box.delete(key);
    notifyListeners();
  }

  /// Discards the local changes, effectively keeping the remote state.
  Future<void> resolveDiscard(String key) async {
    await _box.delete(key);
    notifyListeners();
  }
}

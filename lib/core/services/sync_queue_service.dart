import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/maintenance/models/maintenance_log_model.dart';
import '../exceptions/conflict_exception.dart';
import 'pdf_service.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// The name of the Hive box that holds unsynced operations.
const syncQueueBoxName = 'pending_sync';

const _maintenancePhotosBucket = 'maintenance-photos';
const _maintenanceReportsBucket = 'maintenance-reports';
const _statusPending = 'pending';
const _statusPdfPending = 'pdf_pending';
const _statusConflictDetected = 'conflict_detected';

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

  static const _uuid = Uuid();

  Box<String> get _box => Hive.box<String>(syncQueueBoxName);

  /// Number of items currently waiting to be synced.
  int get pendingCount => _box.values.where((raw) {
    try {
      final item = jsonDecode(raw) as Map<String, dynamic>;
      return item['status'] != _statusConflictDetected;
    } catch (_) {
      return true;
    }
  }).length;

  /// Number of items with conflicts.
  int get conflictCount => _box.values.where((raw) {
    try {
      final item = jsonDecode(raw) as Map<String, dynamic>;
      return item['status'] == _statusConflictDetected;
    } catch (_) {
      return false;
    }
  }).length;

  /// Whether there are items waiting in the queue.
  bool get hasPending => pendingCount > 0;

  /// Get conflicted items
  List<Map<String, dynamic>> get conflictedItems {
    return _box.keys
        .map((key) {
          final raw = _box.get(key);
          if (raw == null) return null;
          try {
            final item = jsonDecode(raw) as Map<String, dynamic>;
            if (item['status'] == _statusConflictDetected) {
              return {'key': key, ...item};
            }
          } catch (_) {}
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
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
    final id = _uuid.v4();
    final item = jsonEncode({
      'id': id,
      'type': type,
      'payload': payload,
      'queued_at': DateTime.now().toIso8601String(),
      'status': _statusPending,
    });
    await _box.put(id, item);
    notifyListeners();
  }

  // ── Flush ─────────────────────────────────────────────────────────────────

  bool _isFlushing = false;

  /// Processes every queued item in chronological order.
  ///
  /// Items that succeed are removed from the box.
  /// Items that fail are kept for the next attempt.
  Future<SyncResult> flush(SupabaseClient client) async {
    if (_isFlushing) return const SyncResult(synced: 0, failed: 0);
    _isFlushing = true;
    try {
      // Sort keys so we replay in the order they were queued.
      final keys = _box.keys.cast<String>().toList()..sort();

      int synced = 0;
      int failed = 0;
      final Map<String, int> versionMap = {};

      for (final key in keys) {
        final raw = _box.get(key);
        if (raw == null) continue;

        try {
          final item = jsonDecode(raw) as Map<String, dynamic>;

          if (item['status'] == _statusConflictDetected) {
            failed++;
            continue; // Skip conflicted items, they require manual resolution
          }

          await _processWithVersionTracking(client, item, key, versionMap);
          await _box.delete(key);
          synced++;
        } on ConflictException catch (e) {
          final item = jsonDecode(raw) as Map<String, dynamic>;
          item['status'] = _statusConflictDetected;
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
    } finally {
      _isFlushing = false;
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _processWithVersionTracking(
    SupabaseClient client,
    Map<String, dynamic> item,
    String key,
    Map<String, int> versionMap,
  ) async {
    final type = item['type'] as String;
    final payload = Map<String, dynamic>.from(item['payload'] as Map);

    if (type == SyncItemType.elevatorUpdate) {
      final elevatorId = payload['id'] as String;
      if (versionMap.containsKey(elevatorId)) {
        payload['base_version'] = versionMap[elevatorId]!;
      }
      await _syncElevatorUpdate(client, payload);
      versionMap[elevatorId] = (payload['base_version'] as int) + 1;
      return;
    }
    
    await _process(client, item, key);
  }

  Future<void> _process(
    SupabaseClient client,
    Map<String, dynamic> item,
    String key,
  ) async {
    final type = item['type'] as String;
    final payload = Map<String, dynamic>.from(item['payload'] as Map);

    switch (type) {
      case SyncItemType.maintenanceLog:
        await _syncMaintenanceLog(client, payload, item, key);
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
    SupabaseClient client,
    Map<String, dynamic> payload,
    Map<String, dynamic> queueItem,
    String key,
  ) async {
    // Strip internal metadata before inserting.
    final elevatorId = payload['elevator_id'] as String?;
    final technicianId = payload['technician_id'] as String?;

    if (queueItem['status'] == _statusPdfPending) {
      await _generateUploadAndAttachPdf(
        client,
        _pdfPendingRemoteState(queueItem),
      );
      await _completeMatchingSchedule(
        client,
        elevatorId: elevatorId,
        technicianId: technicianId,
        maintenanceDate: payload['maintenance_date'] as String?,
      );
      return;
    }

    final row = Map<String, dynamic>.from(payload)
      ..remove('_complete_schedule');

    final rawPhotos = row['photos'];
    if (rawPhotos is List) {
      final photoPaths = rawPhotos.whereType<String>().toList();
      if (photoPaths.isNotEmpty) {
        final uploadedUrls = await _resolveMaintenancePhotos(
          client,
          photoPaths,
          elevatorId: elevatorId,
          technicianId: technicianId,
        );
        if (uploadedUrls.isNotEmpty) {
          row['photos'] = uploadedUrls;
        } else {
          row.remove('photos');
        }
      } else {
        row.remove('photos');
      }
    } else {
      row.remove('photos');
    }

    final sigPath = row['signature_url'] as String?;
    if (sigPath != null) {
      final url = await _resolveMaintenanceSignature(
        client,
        sigPath,
        elevatorId: elevatorId,
        technicianId: technicianId,
      );
      row['signature_url'] = url;
    }

    final custSigPath = row['customer_signature_url'] as String?;
    if (custSigPath != null) {
      final url = await _resolveMaintenanceSignature(
        client,
        custSigPath,
        elevatorId: elevatorId,
        technicianId: technicianId,
      );
      row['customer_signature_url'] = url;
    }

    final response = await client
        .from('maintenance_logs')
        .insert(row)
        .select()
        .maybeSingle();
    if (response == null) {
      throw StateError('Maintenance log insert returned no row.');
    }
    queueItem['status'] = _statusPdfPending;
    queueItem['payload'] = row;
    queueItem['remote_state'] = response;
    await _box.put(key, jsonEncode(queueItem));

    // ignore: unnecessary_null_comparison
    if (response != null) {
      await _generateUploadAndAttachPdf(client, response);
    }

    await _completeMatchingSchedule(
      client,
      elevatorId: elevatorId,
      technicianId: technicianId,
      maintenanceDate: payload['maintenance_date'] as String?,
    );
  }

  Map<String, dynamic> _pdfPendingRemoteState(Map<String, dynamic> queueItem) {
    final remoteState = queueItem['remote_state'];
    if (remoteState is Map<String, dynamic>) {
      return remoteState;
    }
    if (remoteState is Map) {
      return Map<String, dynamic>.from(remoteState);
    }

    throw StateError('Maintenance log is pdf_pending without remote_state.');
  }

  Future<void> _generateUploadAndAttachPdf(
    SupabaseClient client,
    Map<String, dynamic> response,
  ) async {
    try {
      final logModel = MaintenanceLogModel.fromJson(response);
      final checklistDetails = logModel.checklist?.entries.map(
        (e) => ChecklistItem(label: e.key, isPassed: e.value == true)
      ).toList() ?? <ChecklistItem>[];

      final pdfFile = await PdfService().generateMaintenanceReport(
        log: logModel,
        checklistDetails: checklistDetails,
        mediaUrls: logModel.photos,
        signatureUrl: logModel.signatureUrl,
        customerSignatureUrl: logModel.customerSignatureUrl,
      );

      final fileName =
          'report_${logModel.elevatorId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await client.storage
          .from(_maintenanceReportsBucket)
          .upload(fileName, pdfFile);

      final publicUrl = client.storage
          .from(_maintenanceReportsBucket)
          .getPublicUrl(fileName);
      await client
          .from('maintenance_logs')
          .update({'pdf_url': publicUrl})
          .eq('id', logModel.id);
      debugPrint('[SyncQueue] PDF uploaded & linked: $publicUrl');

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
              'data': {'route': '/customer', 'pdf_url': publicUrl},
            },
          );
          debugPrint('[SyncQueue] Customer notification sent to: $customerId');
        } else {
          debugPrint(
            '[SyncQueue] No customer profile found for elevator ${logModel.elevatorId}. Skipping notification.',
          );
        }
      } catch (notifErr) {
        debugPrint(
          '[SyncQueue] Customer notification failed (non-fatal): $notifErr',
        );
      }
    } catch (e) {
      debugPrint('[SyncQueue] Failed to generate or upload PDF report: $e');
      throw Exception('PDF generation/upload failed');
    }
  }

  Future<String> _resolveMaintenanceSignature(
    SupabaseClient client,
    String path, {
    required String? elevatorId,
    required String? technicianId,
  }) async {
    if (_isRemoteUrl(path)) return path;

    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Maintenance signature is missing', path);
    }

    final urls = await _resolveMaintenancePhotos(
      client,
      [path],
      elevatorId: elevatorId,
      technicianId: technicianId,
    );
    if (urls.isEmpty) {
      throw FileSystemException(
        'Maintenance signature could not be uploaded',
        path,
      );
    }

    return urls.first;
  }

  Future<void> _completeMatchingSchedule(
    SupabaseClient client, {
    required String? elevatorId,
    required String? technicianId,
    String? maintenanceDate,
  }) async {
    if (elevatorId == null || technicianId == null) return;

    try {
      final targetDate = maintenanceDate != null
          ? DateTime.parse(maintenanceDate)
          : DateTime.now();
      final start = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      ).toIso8601String();
      final end = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        23,
        59,
        59,
      ).toIso8601String();

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

  Future<List<String>> _resolveMaintenancePhotos(
    SupabaseClient client,
    List<String> photoPaths, {
    required String? elevatorId,
    required String? technicianId,
  }) async {
    final storage = client.storage.from(_maintenancePhotosBucket);
    final uploadedUrls = <String>[];
    var index = 0;

    for (final path in photoPaths) {
      if (_isRemoteUrl(path)) {
        uploadedUrls.add(path);
        continue;
      }

      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[SyncQueue] Missing photo at $path; skipping.');
        continue;
      }

      final extension = _safeExtension(path);
      final fileName =
          'maintenance_logs/${elevatorId ?? 'unknown'}/${technicianId ?? 'unknown'}_${DateTime.now().millisecondsSinceEpoch}_$index.$extension';
      index++;

      await storage.upload(fileName, file);
      uploadedUrls.add(storage.getPublicUrl(fileName));
    }

    return uploadedUrls;
  }

  bool _isRemoteUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  String _safeExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return 'jpg';
    }

    final extension = path.substring(dotIndex + 1).toLowerCase();
    if (extension.length > 5) {
      return 'jpg';
    }

    return extension;
  }

  Future<void> _syncFaultReport(
    SupabaseClient client,
    Map<String, dynamic> payload,
  ) async {
    await client.from('fault_reports').insert(payload);
  }

  Future<void> _syncElevatorUpdate(
    SupabaseClient client,
    Map<String, dynamic> payload,
  ) async {
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
      final remote = await client
          .from('elevators')
          .select()
          .eq('id', id)
          .maybeSingle();
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

    final remote = await client
        .from('elevators')
        .select('version')
        .eq('id', id)
        .maybeSingle();
    if (remote != null) {
      payload['base_version'] = remote['version'];
      item['status'] = _statusPending;
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

    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User not authenticated during conflict resolution.');
    }

    await client.from('conflict_reports').insert({
      'elevator_id': id,
      'technician_id': userId,
      'local_payload': payload,
      'remote_payload': remoteState,
      'status': _statusPending,
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

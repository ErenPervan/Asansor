import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/sync_task.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// The name of the Hive box that holds unsynced operations.
const syncQueueBoxName = 'pending_sync';

/// Supported endpoint identifiers for queued tasks.
abstract final class SyncEndpoint {
  static const insertMaintenanceLog = 'insert_maintenance_log';
  static const insertFaultReport = 'insert_fault_report';
  static const insertInspectionUpdate = 'insert_inspection_update';
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
/// Each task can carry local media paths. Media uploads are performed first and
/// tracked incrementally so sync can resume safely after interruptions.
class SyncQueueService extends ChangeNotifier {
  SyncQueueService();

  Box<SyncTask> get _box => Hive.box<SyncTask>(syncQueueBoxName);

  /// Number of items currently waiting to be synced.
  int get pendingCount => _box.length;

  /// Whether there are items waiting in the queue.
  bool get hasPending => pendingCount > 0;

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Saves [payload] as a pending operation targeting [endpoint].
  Future<void> enqueue({
    required String endpoint,
    required Map<String, dynamic> payload,
    List<String> localMediaPaths = const [],
  }) async {
    final task = SyncTask(
      id: const Uuid().v4(),
      endpoint: endpoint,
      payload: Map<String, dynamic>.from(payload),
      localMediaPaths: List<String>.from(localMediaPaths),
      uploadedMediaUrls: const [],
      isMediaFullyUploaded: localMediaPaths.isEmpty,
      createdAt: DateTime.now().toUtc(),
    );

    await _box.put(task.id, task);
    notifyListeners();
  }

  // ── Flush ─────────────────────────────────────────────────────────────────

  /// Processes every queued item in chronological order.
  ///
  /// Items that succeed are removed from the box.
  /// Items that fail are kept for the next attempt.
  Future<SyncResult> flush(SupabaseClient client) async {
    final tasks = _box.values.toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

    int synced = 0;
    int failed = 0;

    for (final task in tasks) {
      try {
        await _processTask(client, task);
        await _box.delete(task.id);
        synced++;
      } catch (e, stack) {
        failed++;
        debugPrint('[SyncQueueService] Task ${task.id} failed: $e');
        debugPrint('$stack');
      }
    }

    if (synced > 0 || failed == 0) {
      notifyListeners();
    }

    return SyncResult(synced: synced, failed: failed);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _processTask(SupabaseClient client, SyncTask task) async {
    final current = await _ensureMediaState(client, task);
    final cleanedPayload = _cleanPayload(current.payload);

    switch (current.endpoint) {
      case SyncEndpoint.insertMaintenanceLog:
        final scheduleId = current.payload['_schedule_id'] as String?;
        await _syncMaintenanceLog(client, cleanedPayload,
            scheduleId: scheduleId);
        break;
      case SyncEndpoint.insertFaultReport:
        await _syncFaultReport(client, cleanedPayload);
        break;
      case SyncEndpoint.insertInspectionUpdate:
        await _syncInspectionUpdate(client, cleanedPayload);
        break;
      default:
        await _executeEndpoint(client, current.endpoint, cleanedPayload);
    }
  }

  Future<SyncTask> _ensureMediaState(
      SupabaseClient client, SyncTask task) async {
    var current = task;

    if (current.localMediaPaths.isEmpty) {
      if (!current.isMediaFullyUploaded) {
        current = current.copyWith(isMediaFullyUploaded: true);
        await _box.put(current.id, current);
      }
      return current;
    }

    if (!current.isMediaFullyUploaded) {
      current = await _uploadMissingMedia(client, current);
      if (current.uploadedMediaUrls.length ==
          current.localMediaPaths.length) {
        final payload = _injectMediaUrls(current);
        current = current.copyWith(
          isMediaFullyUploaded: true,
          payload: payload,
        );
        await _box.put(current.id, current);
      }
    } else {
      final payload = _injectMediaUrls(current);
      if (!_payloadEquals(payload, current.payload)) {
        current = current.copyWith(payload: payload);
        await _box.put(current.id, current);
      }
    }

    return current;
  }

  Future<SyncTask> _uploadMissingMedia(
      SupabaseClient client, SyncTask task) async {
    final startIndex = task.uploadedMediaUrls.length;
    if (startIndex >= task.localMediaPaths.length) {
      return task;
    }

    final folder = _buildStorageFolder(task);

    var current = task;
    for (var i = startIndex; i < current.localMediaPaths.length; i++) {
      final path = current.localMediaPaths[i];
      final bucket = _resolveBucketForPath(task, path);
      final url = await _uploadMediaFile(
        client,
        path,
        bucketName: bucket,
        folderPath: folder,
      );

      final uploaded = List<String>.from(current.uploadedMediaUrls)..add(url);
      current = current.copyWith(uploadedMediaUrls: uploaded);
      await _box.put(current.id, current);
    }

    return current;
  }

  Future<String> _uploadMediaFile(
    SupabaseClient client,
    String path, {
    required String bucketName,
    required String folderPath,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Missing media file: $path');
    }

    final ext = path.contains('.') ? path.split('.').last : '';
    final name =
        ext.isEmpty ? const Uuid().v4() : '${const Uuid().v4()}.$ext';
    final fullPath = '$folderPath/$name';

    try {
      await client.storage.from(bucketName).upload(fullPath, file);
      return client.storage.from(bucketName).getPublicUrl(fullPath);
    } on StorageException catch (e) {
      throw Exception('Storage upload failed: ${e.message}');
    }
  }

  String _resolveBucketForPath(SyncTask task, String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.pdf')) {
      return 'maintenance-reports';
    }

    final override = task.payload['_media_bucket'] as String?;
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }

    final endpoint = task.endpoint.toLowerCase();
    if (endpoint.contains('fault')) {
      return 'fault-images';
    }

    return 'maintenance-records';
  }

  String _buildStorageFolder(SyncTask task) {
    final safeEndpoint =
        task.endpoint.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'sync/$safeEndpoint/${task.id}';
  }

  Map<String, dynamic> _injectMediaUrls(SyncTask task) {
    final payload = Map<String, dynamic>.from(task.payload);
    final mediaFields = (payload['_media_fields'] as List?)
        ?.map((e) => e.toString())
        .toList();
    final listFields = (payload['_media_list_fields'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};

    payload.remove('_media_fields');
    payload.remove('_media_list_fields');
    payload.remove('_media_bucket');

    if (task.uploadedMediaUrls.isEmpty) {
      return payload;
    }

    if (mediaFields != null &&
        mediaFields.length == task.uploadedMediaUrls.length) {
      final grouped = <String, List<String>>{};
      for (var i = 0; i < mediaFields.length; i++) {
        final field = mediaFields[i];
        final url = task.uploadedMediaUrls[i];
        grouped.putIfAbsent(field, () => []).add(url);
      }

      grouped.forEach((field, urls) {
        final forceList = listFields.contains(field);
        payload[field] = forceList || urls.length > 1 ? urls : urls.first;
      });

      return payload;
    }

    if (task.uploadedMediaUrls.length == 1) {
      payload['media_url'] = task.uploadedMediaUrls.first;
    } else {
      payload['media_urls'] = List<String>.from(task.uploadedMediaUrls);
    }

    return payload;
  }

  bool _payloadEquals(Map<String, dynamic> left, Map<String, dynamic> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      final value = right[entry.key];
      if (entry.value is List && value is List) {
        final leftList = entry.value as List;
        if (leftList.length != value.length) return false;
        for (var i = 0; i < leftList.length; i++) {
          if (leftList[i] != value[i]) return false;
        }
      } else if (entry.value != value) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _cleanPayload(Map<String, dynamic> payload) {
    final cleaned = Map<String, dynamic>.from(payload);
    cleaned.removeWhere((key, _) => key.startsWith('_'));
    return cleaned;
  }

  Future<void> _executeEndpoint(
    SupabaseClient client,
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    if (endpoint.startsWith('function:')) {
      final name = endpoint.substring('function:'.length);
      final response = await client.functions.invoke(name, body: payload);
      if (response.status < 200 || response.status >= 300) {
        throw Exception('Function $name failed (${response.status})');
      }
      return;
    }

    if (endpoint.startsWith('rpc:')) {
      final name = endpoint.substring('rpc:'.length);
      await client.rpc(name, params: payload);
      return;
    }

    if (endpoint.startsWith('table:')) {
      final table = endpoint.substring('table:'.length);
      await client.from(table).insert(payload);
      return;
    }

    await client.from(endpoint).insert(payload);
  }

  Future<void> _syncMaintenanceLog(
    SupabaseClient client,
    Map<String, dynamic> payload, {
    String? scheduleId,
  }) async {
    final elevatorId = payload['elevator_id'] as String?;
    final technicianId = payload['technician_id'] as String?;

    await client.from('maintenance_logs').insert(payload);

    if (elevatorId == null || technicianId == null) {
      return;
    }

    try {
      if (scheduleId != null) {
        await client
            .from('maintenance_schedules')
            .update({'status': 'completed'})
            .eq('id', scheduleId)
            .inFilter('status', ['pending', 'in_progress']);
      } else {
        final dateStr = payload['maintenance_date'] as String?;
        final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();

        final start = DateTime.utc(date.year, date.month, date.day)
            .toIso8601String();
        final nextDay =
            DateTime.utc(date.year, date.month, date.day).add(const Duration(days: 1));
        final end = nextDay.toIso8601String();

        await client
            .from('maintenance_schedules')
            .update({'status': 'completed'})
            .eq('elevator_id', elevatorId)
            .eq('technician_id', technicianId)
            .inFilter('status', ['pending', 'in_progress'])
            .gte('scheduled_date', start)
            .lt('scheduled_date', end);
      }
    } catch (e) {
      debugPrint('[SyncQueueService] Schedule update failed: $e');
    }
  }

  Future<void> _syncFaultReport(
      SupabaseClient client, Map<String, dynamic> payload) async {
    await client.from('fault_reports').insert(payload);
  }

  Future<void> _syncInspectionUpdate(
      SupabaseClient client, Map<String, dynamic> payload) async {
    final elevatorId = payload['elevator_id'] as String;
    final technicianId = payload['technician_id'] as String;
    final inspectionDate = payload['inspection_date'] as String;
    final status = payload['status'] as String;
    final inspectorName = payload['inspector_name'] as String?;
    final notes = payload['notes'] as String?;
    final nextInspectionDate = payload['next_inspection_date'] as String;

    await client.from('inspection_history').insert({
      'elevator_id': elevatorId,
      'technician_id': technicianId,
      'inspection_date': inspectionDate,
      'status': status,
      'inspector_name': inspectorName,
      'notes': notes,
    });

    await client.from('elevators').update({
      'inspection_status': status,
      'last_inspection_date': inspectionDate,
      'next_inspection_date': nextInspectionDate,
    }).eq('id', elevatorId);
  }
}

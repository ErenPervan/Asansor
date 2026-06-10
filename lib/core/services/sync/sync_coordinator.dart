import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asansor/core/exceptions/conflict_exception.dart';
import 'package:asansor/core/services/sync/sync_queue_storage.dart';
import 'package:asansor/core/services/sync/sync_media_uploader.dart';
import 'package:asansor/core/services/sync/sync_remote_writer.dart';
import 'package:asansor/core/services/sync/sync_conflict_resolver.dart';

export 'package:asansor/core/services/sync/sync_queue_storage.dart'
    show SyncItemType, syncQueueBoxName;

class SyncResult {
  const SyncResult({required this.synced, required this.failed});

  final int synced;
  final int failed;

  bool get hasFailures => failed > 0;

  @override
  String toString() => 'SyncResult(synced: $synced, failed: $failed)';
}

class SyncCoordinator extends ChangeNotifier {
  final SyncQueueStorage _storage;
  SyncMediaUploader? _mediaUploader;
  SyncRemoteWriter? _remoteWriter;
  SyncConflictResolver? _conflictResolver;

  @visibleForTesting
  set overrideRemoteWriter(SyncRemoteWriter writer) => _remoteWriter = writer;

  SyncCoordinator() : _storage = SyncQueueStorage() {
    _storage.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _storage.removeListener(notifyListeners);
    _storage.dispose();
    super.dispose();
  }

  int get pendingCount => _storage.pendingCount;
  int get conflictCount => _storage.conflictCount;
  int get failedCount => _storage.failedCount;
  bool get hasPending => _storage.hasPending;
  List<Map<String, dynamic>> get conflictedItems => _storage.conflictedItems;
  List<Map<String, dynamic>> get pendingItems => _storage.pendingItems;

  Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload,
  }) => _storage.enqueue(type: type, payload: payload);

  bool _isFlushing = false;

  Future<SyncResult> flush(SupabaseClient client) async {
    if (_isFlushing) return const SyncResult(synced: 0, failed: 0);
    _isFlushing = true;

    _mediaUploader ??= SyncMediaUploader(client);
    _remoteWriter ??= SyncRemoteWriter(client, _mediaUploader!, _storage);
    _conflictResolver ??= SyncConflictResolver(
      client,
      _storage,
      () => flush(client),
    );

    try {
      final keys = _storage.keys;

      int synced = 0;
      int failed = 0;
      final Map<String, int> versionMap = {};

      for (final key in keys) {
        final raw = _storage.get(key);
        if (raw == null) continue;

        try {
          final item = jsonDecode(raw) as Map<String, dynamic>;

          if (item['status'] == statusConflictDetected ||
              item['status'] == statusDeadLetter ||
              item['status'] == statusResolving) {
            failed++;
            continue;
          }

          if (item['next_retry_at'] != null) {
            final nextRetryAt = DateTime.tryParse(
              item['next_retry_at'] as String,
            );
            if (nextRetryAt != null && nextRetryAt.isAfter(DateTime.now())) {
              failed++; // Count as failed for this flush so UI knows it's pending/failed
              continue;
            }
          }

          final type = item['type'] as String;
          final payload = Map<String, dynamic>.from(item['payload'] as Map);

          if (type == SyncItemType.elevatorUpdate) {
            final elevatorId = payload['id'] as String;
            if (versionMap.containsKey(elevatorId)) {
              payload['base_version'] = versionMap[elevatorId]!;
            }
            await _remoteWriter!.syncElevatorUpdate(payload);
            versionMap[elevatorId] = (payload['base_version'] as int) + 1;
          } else {
            switch (type) {
              case SyncItemType.maintenanceLog:
                await _remoteWriter!.syncMaintenanceLog(payload, item, key);
                break;
              case SyncItemType.faultReport:
                await _remoteWriter!.syncFaultReport(payload, item['id']);
                break;
              case SyncItemType.faultResolve:
                await _remoteWriter!.syncFaultResolve(payload);
                break;
              case SyncItemType.faultReopen:
                await _remoteWriter!.syncFaultReopen(payload);
                break;
              default:
                throw UnsupportedError('Unknown sync type: $type');
            }
          }

          await _storage.delete(key);
          synced++;
        } on ConflictException catch (e) {
          final item = jsonDecode(raw) as Map<String, dynamic>;
          item['status'] = statusConflictDetected;
          item['remote_state'] = e.remoteState;
          await _storage.put(key, jsonEncode(item));
          failed++;
        } catch (e, s) {
          debugPrint('[SyncCoordinator] Unexpected error in flush: $e\n$s');
          final item = jsonDecode(raw) as Map<String, dynamic>;

          if (_remoteWriter!.isTerminalError(e)) {
            item['status'] = statusDeadLetter;
            item['error_details'] = e.toString();
          } else {
            // Transient error: apply exponential backoff
            final retryCount = (item['retry_count'] as int?) ?? 0;
            if (retryCount >= 5) {
              item['status'] = statusDeadLetter;
              item['error_details'] =
                  'Max retries exceeded (5). Last error: $e';
            } else {
              item['retry_count'] = retryCount + 1;
              final delaySeconds = (pow(2, retryCount) * 5).toInt();
              final jitter = Random().nextInt(5);
              final maxDelay = min(delaySeconds + jitter, 1800); // Max 30 mins
              final nextRetry = DateTime.now().add(Duration(seconds: maxDelay));
              item['next_retry_at'] = nextRetry.toIso8601String();
            }
          }
          await _storage.put(key, jsonEncode(item));
          failed++;
        }
      }

      // Always notify listeners after a flush attempt so the UI updates
      // its conflict/failed badges.
      _storage.triggerNotify();

      return SyncResult(synced: synced, failed: failed);
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> resolveForceUpdate(SupabaseClient client, String key) async {
    _conflictResolver ??= SyncConflictResolver(
      client,
      _storage,
      () => flush(client),
    );
    await _conflictResolver!.resolveForceUpdate(key);
  }

  Future<void> resolveFlagDisputed(SupabaseClient client, String key) async {
    _conflictResolver ??= SyncConflictResolver(
      client,
      _storage,
      () => flush(client),
    );
    await _conflictResolver!.resolveFlagDisputed(key);
  }

  Future<void> resolveDiscard(SupabaseClient client, String key) async {
    _conflictResolver ??= SyncConflictResolver(client, _storage, () async {});
    await _conflictResolver!.resolveDiscard(key);
  }
}

/// Backward compatibility alias
typedef SyncQueueService = SyncCoordinator;

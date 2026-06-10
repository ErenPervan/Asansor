import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asansor/core/services/sync/sync_queue_storage.dart';

class SyncConflictResolver {
  final SupabaseClient _client;
  final SyncQueueStorage _storage;
  final Future<void> Function() _onFlushRequired;

  SyncConflictResolver(this._client, this._storage, this._onFlushRequired);

  Future<void> resolveForceUpdate(String key) async {
    final raw = _storage.get(key);
    if (raw == null) return;

    final item = jsonDecode(raw) as Map<String, dynamic>;
    final payload = item['payload'] as Map<String, dynamic>;
    final id = payload['id'] as String;

    final remote = await _client
        .from('elevators')
        .select('version')
        .eq('id', id)
        .maybeSingle();

    if (remote != null) {
      payload['base_version'] = remote['version'];
      item['status'] = statusPending;
      item.remove('remote_state');
      await _storage.put(key, jsonEncode(item));

      await _onFlushRequired();
    }
  }

  Future<void> resolveFlagDisputed(String key) async {
    final raw = _storage.get(key);
    if (raw == null) return;

    final item = jsonDecode(raw) as Map<String, dynamic>;
    final payload = item['payload'] as Map<String, dynamic>;
    final id = payload['id'] as String;
    final remoteState = item['remote_state'] as Map<String, dynamic>;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User not authenticated during conflict resolution.');
    }

    // 1. Mark as resolving
    item['status'] = statusResolving;
    await _storage.put(key, jsonEncode(item));
    _storage.triggerNotify();

    try {
      // 2. Insert report
      await _client.from('conflict_reports').insert({
        'elevator_id': id,
        'technician_id': userId,
        'local_payload': payload,
        'remote_payload': remoteState,
        'status': statusPending,
      });

      // 3. Delete upon success
      await _storage.delete(key);
      _storage.triggerNotify();
    } catch (e) {
      // 4. Revert status upon failure
      item['status'] = statusConflictDetected;
      await _storage.put(key, jsonEncode(item));
      _storage.triggerNotify();
      rethrow;
    }
  }

  Future<void> resolveDiscard(String key) async {
    await _storage.delete(key);
    _storage.triggerNotify();
  }
}

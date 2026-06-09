import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asansor/core/services/sync/queue/sync_item.dart';
import 'package:asansor/core/services/sync/queue/sync_queue_repository.dart';
import 'package:asansor/core/services/sync/media/media_upload_service.dart';
import 'package:asansor/core/services/sync/coordinator/sync_coordinator.dart';

export 'package:asansor/core/services/sync/queue/sync_item.dart' show syncQueueBoxName, SyncItemType, SyncResult;

/// Proxy service maintaining UI backwards compatibility by delegating
/// to specialized sub-components.
class SyncQueueService extends ChangeNotifier {
  SyncQueueService() {
    _repository = SyncQueueRepository();
    _mediaUploadService = MediaUploadService();
    _coordinator = SyncCoordinator(
      repository: _repository,
      mediaUploadService: _mediaUploadService,
      notifyListeners: notifyListeners,
    );
  }

  late final SyncQueueRepository _repository;
  late final MediaUploadService _mediaUploadService;
  late final SyncCoordinator _coordinator;

  int get pendingCount => _repository.pendingCount;

  int get conflictCount => _repository.conflictCount;

  bool get hasPending => _repository.hasPending;

  List<Map<String, dynamic>> get conflictedItems => _repository.conflictedItems;
  List<Map<String, dynamic>> get failedItems => _repository.failedItems;
  int get deadLetterCount => _repository.deadLetterCount;

  List<Map<String, dynamic>> pendingItemsOfType(String type) =>
      _repository.pendingItemsOfType(type);

  Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    await _repository.enqueue(type: type, payload: payload);
    notifyListeners();
  }

  Future<SyncResult> flush(SupabaseClient client) => _coordinator.flush(client);

  Future<void> resolveForceUpdate(SupabaseClient client, String key) =>
      _coordinator.resolveForceUpdate(client, key);

  Future<void> resolveFlagDisputed(SupabaseClient client, String key) =>
      _coordinator.resolveFlagDisputed(client, key);

  Future<void> resolveDiscard(String key) => _coordinator.resolveDiscard(key);
}

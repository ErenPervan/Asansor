import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';

enum SyncState { online, offline, syncing, syncError, syncConflict }

final syncStatusProvider = Provider<SyncState>((ref) {
  final isOnline = ref.watch(isOnlineProvider);
  final pendingCount = ref.watch(pendingSyncCountProvider);
  final failedCount = ref.watch(failedSyncCountProvider);
  final conflictCount = ref.watch(conflictSyncCountProvider);

  if (!isOnline) {
    return SyncState.offline;
  }

  if (failedCount > 0) {
    return SyncState.syncError;
  }

  if (conflictCount > 0) {
    return SyncState.syncConflict;
  }

  if (pendingCount > 0) {
    return SyncState.syncing;
  }

  return SyncState.online;
});

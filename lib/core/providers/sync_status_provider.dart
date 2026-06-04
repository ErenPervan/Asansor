import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_providers.dart';

enum SyncState { online, offline, syncing, syncError }

final syncStatusProvider = Provider<SyncState>((ref) {
  final isOnline = ref.watch(isOnlineProvider);
  final pendingCount = ref.watch(pendingSyncCountProvider);

  if (!isOnline) {
    return SyncState.offline;
  }

  if (pendingCount > 0) {
    return SyncState.syncing;
  }

  return SyncState.online;
});

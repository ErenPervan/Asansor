import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/sync_queue_service.dart';

// ── Connectivity ──────────────────────────────────────────────────────────────

/// Streams the current list of [ConnectivityResult]s whenever the network
/// state changes. `connectivity_plus` v6 returns a `List<>` per event.
final connectivityStreamProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// `true` when at least one non-`none` connectivity result is present.
///
/// Defaults to `true` while the stream is loading to avoid false "offline"
/// flickers on cold start.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).when(
        data: (results) =>
            results.any((r) => r != ConnectivityResult.none),
        loading: () => true,
        error: (e, st) => true,
      );
});

// ── Sync Queue ────────────────────────────────────────────────────────────────

/// Single shared [SyncQueueService] instance backed by the open Hive box.
///
/// Uses `ChangeNotifierProvider` so widgets watching
/// [pendingSyncCountProvider] automatically rebuild when the queue changes.
final syncQueueServiceProvider =
    ChangeNotifierProvider<SyncQueueService>((ref) {
  return SyncQueueService();
});

/// Exposes the number of items currently waiting in the offline queue.
///
/// Rebuilds whenever [SyncQueueService] calls `notifyListeners()`.
final pendingSyncCountProvider = Provider<int>((ref) {
  return ref.watch(syncQueueServiceProvider).pendingCount;
});

// ── Auto-sync ─────────────────────────────────────────────────────────────────

/// Watches the connectivity stream and automatically flushes the queue the
/// moment the device comes back online.
///
/// Must be kept alive by `ref.watch`-ing it somewhere in the widget tree
/// (e.g. inside [HomeView]).
final autoSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<ConnectivityResult>>>(
    connectivityStreamProvider,
    (previous, next) {
      next.whenData((results) {
        final wasOffline = previous?.valueOrNull
                ?.every((r) => r == ConnectivityResult.none) ??
            false;
        final isNowOnline =
            results.any((r) => r != ConnectivityResult.none);

        if (isNowOnline && wasOffline) {
          final queue = ref.read(syncQueueServiceProvider);
          if (queue.hasPending) {
            queue.flush(Supabase.instance.client);
          }
        }
      });
    },
  );
});

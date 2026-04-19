import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/read_cache_service.dart';
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

// ── Read Cache ────────────────────────────────────────────────────────────────

/// Single shared [ReadCacheService] instance backed by the open Hive boxes.
///
/// The boxes (`elevators_cache` and `tasks_cache`) must be opened in `main.dart`
/// before this provider is first read.
final readCacheServiceProvider = Provider<ReadCacheService>((ref) {
  return ReadCacheService();
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
/// Also flushes on the very first connectivity event (cold start / app resume)
/// so items queued during a previous offline session are synced as soon as the
/// app launches with an active connection — not only on offline→online
/// transitions.
///
/// Kept alive at the app-root level (watched inside [AsansorApp]) so it runs
/// for the full app lifetime regardless of which screen is visible.
final autoSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<ConnectivityResult>>>(
    connectivityStreamProvider,
    (previous, next) {
      next.whenData((results) {
        final isNowOnline =
            results.any((r) => r != ConnectivityResult.none);
        if (!isNowOnline) return;

        // `previous == null` → first connectivity event after cold start.
        // Treat it the same as "was offline" so any items queued in a prior
        // offline session are flushed immediately on startup.
        final wasOffline = previous == null ||
          (previous.valueOrNull
                    ?.every((r) => r == ConnectivityResult.none) ??
                true);

        if (wasOffline) {
          final queue = ref.read(syncQueueServiceProvider);
          if (queue.hasPending) {
            queue.flush(Supabase.instance.client);
          }
        }
      });
    },
  );
});

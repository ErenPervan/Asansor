import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asansor/core/services/read_cache_service.dart';
import 'package:asansor/core/services/reachability_service.dart';
import 'package:asansor/core/services/sync/sync_coordinator.dart';

// ── Connectivity ──────────────────────────────────────────────────────────────

/// Streams the current list of [ConnectivityResult]s whenever the network
/// state changes. `connectivity_plus` v6 returns a `List<>` per event.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});

/// Periodically tests true internet reachability.
final reachabilityStreamProvider = StreamProvider<ReachabilityStatus>((
  ref,
) async* {
  final connectivity = ref.watch(connectivityStreamProvider);
  final isHardwareOnline = connectivity.when(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    loading: () => true, // Assume true while loading
    error: (_, _) => false,
  );

  if (!isHardwareOnline) {
    yield ReachabilityStatus.offline;
    return;
  }

  // Initial check
  yield await ReachabilityService.instance.checkReachability();

  // Periodic check
  final timer = Stream.periodic(const Duration(seconds: 30));
  await for (final _ in timer) {
    yield await ReachabilityService.instance.checkReachability();
  }
});

/// `true` only when the device has a network connection AND can reach Supabase.
///
/// Defaults to `true` while the stream is loading to avoid false "offline"
/// flickers on cold start.
final isOnlineProvider = Provider<bool>((ref) {
  return ref
      .watch(reachabilityStreamProvider)
      .when(
        data: (status) => status == ReachabilityStatus.online,
        loading: () => true,
        error: (e, st) => true,
      );
});

// ── Supabase Client ───────────────────────────────────────────────────────────

/// Single Riverpod-managed reference to the live [SupabaseClient].
///
/// **Always inject the client through this provider** — never call
/// `Supabase.instance.client` directly inside providers or repositories.
/// This makes every consumer overridable in unit tests:
/// ```dart
/// final container = ProviderContainer(overrides: [
///   supabaseClientProvider.overrideWithValue(mockClient),
/// ]);
/// ```
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
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
final syncQueueServiceProvider = ChangeNotifierProvider<SyncQueueService>((
  ref,
) {
  return SyncQueueService();
});

/// Exposes the number of items currently waiting in the offline queue.
///
/// Rebuilds whenever [SyncQueueService] calls `notifyListeners()`.
final pendingSyncCountProvider = Provider<int>((ref) {
  return ref.watch(syncQueueServiceProvider).pendingCount;
});

// ── Auto-sync ─────────────────────────────────────────────────────────────────

/// Watches the reachability stream and automatically flushes the queue the
/// moment the device comes back online.
///
/// Also flushes on the very first reachability event (cold start / app resume)
/// so items queued during a previous offline session are synced as soon as the
/// app launches with an active connection — not only on offline→online
/// transitions.
///
/// Kept alive at the app-root level (watched inside [AsansorApp]) so it runs
/// for the full app lifetime regardless of which screen is visible.
void setupAutoSyncListener(WidgetRef ref) {
  ref.listen<AsyncValue<ReachabilityStatus>>(reachabilityStreamProvider, (
    previous,
    next,
  ) {
    next.whenData((status) {
      final isNowOnline = status == ReachabilityStatus.online;
      if (!isNowOnline) return;

      // `previous == null` → first connectivity event after cold start.
      // Treat it the same as "was offline" so any items queued in a prior
      // offline session are flushed immediately on startup.
      final wasOffline =
          previous == null || previous.valueOrNull != ReachabilityStatus.online;

      if (wasOffline) {
        final queue = ref.read(syncQueueServiceProvider);
        if (queue.hasPending) {
          queue.flush(ref.read(supabaseClientProvider));
        }
      }
    });
  });
}

// ── Added Sync UI Metrics ───────────────────────────────────────────────────

/// Exposes the number of items that have failed persistently (dead letters).
final failedSyncCountProvider = Provider<int>((ref) {
  return ref.watch(syncQueueServiceProvider).failedCount;
});

/// Exposes the number of items that are in a conflicted state.
final conflictSyncCountProvider = Provider<int>((ref) {
  return ref.watch(syncQueueServiceProvider).conflictCount;
});

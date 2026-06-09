import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asansor/core/services/read_cache_service.dart';
import 'package:asansor/core/services/sync_queue_service.dart';
import 'package:asansor/core/services/reachability_service.dart';

// ── Connectivity ──────────────────────────────────────────────────────────────

/// Streams the current list of [ConnectivityResult]s whenever the network
/// state changes. `connectivity_plus` v6 returns a `List<>` per event.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});

/// `true` when at least one non-`none` connectivity result is present.
///
/// Defaults to `true` while the stream is loading to avoid false "offline"
/// flickers on cold start.
final isOnlineProvider = Provider<bool>((ref) {
  return ref
      .watch(connectivityStreamProvider)
      .when(
        data: (results) => results.any((r) => r != ConnectivityResult.none),
        loading: () => true,
        error: (e, st) => true,
      );
});

final reachabilityServiceProvider = Provider<ReachabilityService>((ref) {
  return ReachabilityService();
});

final isReachableProvider = StateProvider<bool>((ref) => false);

void setupReachabilityListener(WidgetRef ref) {
  Timer? pingTimer;

  void checkReachability() async {
    final client = ref.read(supabaseClientProvider);
    final restUrl = client.rest.url.toString();
    final isReachable = await ref.read(reachabilityServiceProvider).checkSupabase(restUrl);
    ref.read(isReachableProvider.notifier).state = isReachable;
  }

  ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityStreamProvider, (
    previous,
    next,
  ) {
    next.whenData((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      
      pingTimer?.cancel();
      
      if (hasConnection) {
        checkReachability();
        pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => checkReachability());
      } else {
        ref.read(isReachableProvider.notifier).state = false;
      }
    });
  });
}

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

enum SyncHealth { ok, pending, conflict, deadLetter }

final syncHealthProvider = Provider<SyncHealth>((ref) {
  final queueService = ref.watch(syncQueueServiceProvider);
  if (queueService.deadLetterCount > 0) return SyncHealth.deadLetter;
  if (queueService.conflictCount > 0) return SyncHealth.conflict;
  if (queueService.pendingCount > 0) return SyncHealth.pending;
  return SyncHealth.ok;
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
void setupAutoSyncListener(WidgetRef ref) {
  ref.listen<bool>(isReachableProvider, (previous, next) {
    final isNowReachable = next;
    if (!isNowReachable) return;

    final wasUnreachable = previous == null || previous == false;

    if (wasUnreachable) {
      final queue = ref.read(syncQueueServiceProvider);
      if (queue.hasPending) {
        queue.flush(ref.read(supabaseClientProvider));
      }
    }
  });

  // Trigger an initial check on startup
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final queue = ref.read(syncQueueServiceProvider);
    if (queue.hasPending && ref.read(isReachableProvider)) {
      queue.flush(ref.read(supabaseClientProvider));
    }
  });
}

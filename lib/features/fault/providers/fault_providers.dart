import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';
import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/core/services/sync/sync_coordinator.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:asansor/features/fault/repositories/fault_repository.dart';

// ── Repository ──────────────────────────────────────────────────────────────

/// Provides the [FaultRepository] backed by the live Supabase client.
final faultRepositoryProvider = Provider<IFaultRepository>((ref) {
  return FaultRepository(ref.watch(supabaseClientProvider));
});

// ── Data Providers ───────────────────────────────────────────────────────────

/// Fetches all fault reports (resolved and unresolved) across every elevator.
final allFaultsProvider = FutureProvider<List<FaultReportModel>>((ref) async {
  // Try network first if online
  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  if (!isOnline) {
    return cache.loadAllFaults();
  }

  try {
    final repo = ref.watch(faultRepositoryProvider);
    final data = await repo.getAllFaults();
    // Cache the faults for offline use
    unawaited(cache.saveAllFaults(data));
    return data;
  } catch (e) {
    final cached = cache.loadAllFaults().cast<FaultReportModel>();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});

/// Fetches all unresolved fault reports across every elevator.
final activeFaultsProvider = FutureProvider<List<FaultReportModel>>((
  ref,
) async {
  final isOnline = ref.watch(isOnlineProvider);
  // Assume readCacheServiceProvider is imported or accessible. If not, we will need to adjust.
  // wait, I don't know the name of the provider. Let's just create an instance if needed.
  // Wait, I should find readCacheServiceProvider import. I will use ReadCacheService() directly if not provided, or search for it.
  // Actually, I can use ref.read(readCacheServiceProvider) if I know it exists. Let's look at it.

  // To be safe, I'll use the same cache provider we saw in elevator_providers.dart.
  final cache = ref.read(readCacheServiceProvider);

  if (!isOnline) {
    return cache.loadActiveFaults();
  }

  try {
    final repo = ref.watch(faultRepositoryProvider);
    final data = await repo.getAllActiveFaults();
    unawaited(cache.saveActiveFaults(data));
    return data;
  } catch (e) {
    final cached = cache.loadActiveFaults().cast<FaultReportModel>();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});

/// Fetches all fault reports for a given elevator [id].
final faultsByElevatorProvider =
    FutureProvider.family<List<FaultReportModel>, String>((
      ref,
      elevatorId,
    ) async {
      final repo = ref.watch(faultRepositoryProvider);
      return repo.getFaultsByElevatorId(elevatorId);
    });

/// Fetches a single fault report by its [id].
///
/// Usage: `ref.watch(faultByIdProvider('some-uuid'))`
final faultByIdProvider = FutureProvider.autoDispose
    .family<FaultReportModel, String>((ref, faultId) async {
      final repo = ref.watch(faultRepositoryProvider);
      return repo.getFaultById(faultId);
    });

// ── Report Notifier ──────────────────────────────────────────────────────────

/// Holds the state of an in-flight fault report submission.
class FaultController extends AutoDisposeAsyncNotifier<FaultReportModel?> {
  @override
  Future<FaultReportModel?> build() async => null;

  Future<void> reportFault({
    required String elevatorId,
    required String description,
    String? photoUrl,
  }) async {
    state = const AsyncLoading();

    final isOnline = ref.read(isOnlineProvider);

    await ref
        .read(syncQueueServiceProvider)
        .enqueue(
          type: SyncItemType.faultReport,
          payload: {
            'elevator_id': elevatorId,
            'description': description,
            'is_resolved': false,
            'reported_at': DateTime.now().toUtc().toIso8601String(),
            'photo_url': ?photoUrl,
          },
        );

    if (isOnline) {
      await ref
          .read(syncQueueServiceProvider)
          .flush(ref.read(supabaseClientProvider));
      ref.invalidate(activeFaultsProvider);
    }

    state = AsyncData(
      FaultReportModel(
        id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
        elevatorId: elevatorId,
        description: description,
        isResolved: false,
        reportedAt: DateTime.now(),
        isOfflineQueued: !isOnline, // If online, flush might have succeeded
      ),
    );
  }
}

final faultControllerProvider =
    AutoDisposeAsyncNotifierProvider<FaultController, FaultReportModel?>(
      FaultController.new,
    );

// ── Update Notifier (resolve / reopen) ──────────────────────────────────────

/// Manages resolve / reopen operations on an existing fault.
///
/// Automatically invalidates related providers after a successful update so
/// every listener (home screen, detail view, elevator detail) refreshes.
class FaultUpdateController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> resolve(String faultId, {String? resolutionNotes}) async {
    state = const AsyncLoading();
    final isOnline = ref.read(isOnlineProvider);

    await ref
        .read(syncQueueServiceProvider)
        .enqueue(
          type: SyncItemType.faultResolve,
          payload: {
            'fault_id': faultId,
            'resolved_at': DateTime.now().toUtc().toIso8601String(),
            if (resolutionNotes != null && resolutionNotes.isNotEmpty)
              'resolution_notes': resolutionNotes,
          },
        );

    if (isOnline) {
      await ref
          .read(syncQueueServiceProvider)
          .flush(ref.read(supabaseClientProvider));
    }

    state = const AsyncData(null);
    ref.invalidate(activeFaultsProvider);
    ref.invalidate(faultByIdProvider(faultId));
    return true;
  }

  Future<bool> reopen(String faultId) async {
    state = const AsyncLoading();
    final isOnline = ref.read(isOnlineProvider);

    await ref
        .read(syncQueueServiceProvider)
        .enqueue(
          type: SyncItemType.faultReopen,
          payload: {'fault_id': faultId},
        );

    if (isOnline) {
      await ref
          .read(syncQueueServiceProvider)
          .flush(ref.read(supabaseClientProvider));
    }

    state = const AsyncData(null);
    ref.invalidate(activeFaultsProvider);
    ref.invalidate(faultByIdProvider(faultId));
    return true;
  }
}

final faultUpdateControllerProvider =
    AsyncNotifierProvider.autoDispose<FaultUpdateController, void>(
      FaultUpdateController.new,
    );

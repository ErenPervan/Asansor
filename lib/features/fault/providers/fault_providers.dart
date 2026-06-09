import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/core/services/sync_queue_service.dart';
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
  final queueService = ref.watch(syncQueueServiceProvider);
  final pendingPayloads = queueService.pendingItemsOfType(SyncItemType.faultReport);
  final pendingFaults = pendingPayloads.map((p) {
    p['id'] = 'pending_${p['idempotency_key']}';
    return FaultReportModel.fromOfflineQueue(p);
  }).toList();

  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  List<FaultReportModel> remoteFaults = [];
  if (!isOnline) {
    remoteFaults = cache.loadAllFaults();
  } else {
    try {
      final repo = ref.watch(faultRepositoryProvider);
      remoteFaults = await repo.getAllFaults();
      unawaited(cache.saveAllFaults(remoteFaults));
    } catch (e) {
      remoteFaults = cache.loadAllFaults().cast<FaultReportModel>();
      if (remoteFaults.isEmpty) rethrow;
    }
  }

  return [...pendingFaults, ...remoteFaults];
});

/// Fetches all unresolved fault reports across every elevator.
final activeFaultsProvider = FutureProvider<List<FaultReportModel>>((
  ref,
) async {
  final queueService = ref.watch(syncQueueServiceProvider);
  final pendingPayloads = queueService.pendingItemsOfType(SyncItemType.faultReport);
  final pendingFaults = pendingPayloads.map((p) {
    p['id'] = 'pending_${p['idempotency_key']}';
    return FaultReportModel.fromOfflineQueue(p);
  }).where((f) => !f.isResolved).toList();

  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  List<FaultReportModel> remoteFaults = [];
  if (!isOnline) {
    remoteFaults = cache.loadActiveFaults();
  } else {
    try {
      final repo = ref.watch(faultRepositoryProvider);
      remoteFaults = await repo.getAllActiveFaults();
      unawaited(cache.saveActiveFaults(remoteFaults));
    } catch (e) {
      remoteFaults = cache.loadActiveFaults().cast<FaultReportModel>();
      if (remoteFaults.isEmpty) rethrow;
    }
  }

  return [...pendingFaults, ...remoteFaults];
});

/// Fetches all fault reports for a given elevator [id].
final faultsByElevatorProvider =
    FutureProvider.family<List<FaultReportModel>, String>((
      ref,
      elevatorId,
    ) async {
      final queueService = ref.watch(syncQueueServiceProvider);
      final pendingPayloads = queueService.pendingItemsOfType(SyncItemType.faultReport);
      final pendingFaults = pendingPayloads
          .where((p) => p['elevator_id'] == elevatorId)
          .map((p) {
            p['id'] = 'pending_${p['idempotency_key']}';
            return FaultReportModel.fromOfflineQueue(p);
          }).toList();

      final repo = ref.watch(faultRepositoryProvider);
      final remoteFaults = await repo.getFaultsByElevatorId(elevatorId);
      
      return [...pendingFaults, ...remoteFaults];
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
    final idempotencyKey = const Uuid().v4();

    // ── Queue First (Always write to local queue) ───────────────────────────
    await ref.read(syncQueueServiceProvider).enqueue(
          type: SyncItemType.faultReport,
          payload: {
            'idempotency_key': idempotencyKey,
            'elevator_id': elevatorId,
            'description': description,
            'is_resolved': false,
            'reported_at': DateTime.now().toUtc().toIso8601String(),
            'photo_url': ?photoUrl,
          },
        );

    // ── Attempt Sync if Online ──────────────────────────────────────────────
    if (isOnline) {
      // The flush command handles its own errors silently, preserving the queue
      await ref.read(syncQueueServiceProvider).flush(ref.read(supabaseClientProvider));
    }

    state = AsyncData(
      FaultReportModel(
        id: 'queued_${DateTime.now().millisecondsSinceEpoch}',
        elevatorId: elevatorId,
        description: description,
        isResolved: false,
        reportedAt: DateTime.now(),
        isOfflineQueued: true,
      ),
    );

    if (!state.hasError) {
      ref.invalidate(activeFaultsProvider);
    }
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
    state = await AsyncValue.guard(() async {
      await ref
          .read(faultRepositoryProvider)
          .resolveFault(faultId, resolutionNotes: resolutionNotes);
    });

    if (!state.hasError) {
      ref.invalidate(activeFaultsProvider);
      ref.invalidate(faultByIdProvider(faultId));
      return true;
    }
    return false;
  }

  Future<bool> reopen(String faultId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(faultRepositoryProvider).reopenFault(faultId);
    });

    if (!state.hasError) {
      ref.invalidate(activeFaultsProvider);
      ref.invalidate(faultByIdProvider(faultId));
      return true;
    }
    return false;
  }
}

final faultUpdateControllerProvider =
    AsyncNotifierProvider.autoDispose<FaultUpdateController, void>(
      FaultUpdateController.new,
    );

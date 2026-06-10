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

// ── Pending Overlay Helper ───────────────────────────────────────────────────

List<FaultReportModel> _applyPendingModifications(
  Ref ref,
  List<FaultReportModel> faults, {
  String? elevatorId,
  bool activeOnly = false,
}) {
  final queue = ref.watch(syncQueueServiceProvider);
  final pending = queue.pendingItems;

  final Map<String, FaultReportModel> faultMap = {
    for (final f in faults) f.id: f,
  };

  for (final item in pending) {
    if (item['type'] == SyncItemType.faultReport) {
      final payload = item['payload'] as Map<String, dynamic>;
      final newFault = FaultReportModel(
        id: item['id'] as String,
        elevatorId: payload['elevator_id'] as String,
        description: payload['description'] as String,
        isResolved: payload['is_resolved'] as bool,
        reportedAt: DateTime.parse(payload['reported_at'] as String),
        photoUrl: payload['photo_url'] as String?,
        isOfflineQueued: true,
      );
      faultMap[newFault.id] = newFault;
    } else if (item['type'] == SyncItemType.faultResolve) {
      final payload = item['payload'] as Map<String, dynamic>;
      final fId = payload['fault_id'] as String;
      if (faultMap.containsKey(fId)) {
        faultMap[fId] = faultMap[fId]!.copyWith(
          isResolved: true,
          resolvedAt: DateTime.parse(payload['resolved_at'] as String),
          resolutionNotes: payload['resolution_notes'] as String?,
          isOfflineQueued: true,
        );
      }
    } else if (item['type'] == SyncItemType.faultReopen) {
      final payload = item['payload'] as Map<String, dynamic>;
      final fId = payload['fault_id'] as String;
      if (faultMap.containsKey(fId)) {
        faultMap[fId] = faultMap[fId]!.copyWith(
          isResolved: false,
          isOfflineQueued: true,
        );
      }
    }
  }

  return faultMap.values
      .where((f) => elevatorId == null || f.elevatorId == elevatorId)
      .where((f) => !activeOnly || !f.isResolved)
      .toList()
    ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
}

// ── Data Providers ───────────────────────────────────────────────────────────

/// Fetches all fault reports (resolved and unresolved) across every elevator.
final allFaultsProvider = FutureProvider<List<FaultReportModel>>((ref) async {
  // Try network first if online
  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  if (!isOnline) {
    final cached = cache.loadAllFaults();
    return _applyPendingModifications(ref, cached);
  }

  try {
    final repo = ref.watch(faultRepositoryProvider);
    final data = await repo.getAllFaults();
    // Cache the faults for offline use
    unawaited(cache.saveAllFaults(data));
    return _applyPendingModifications(ref, data);
  } catch (e) {
    final cached = cache.loadAllFaults().cast<FaultReportModel>();
    if (cached.isNotEmpty) return _applyPendingModifications(ref, cached);
    rethrow;
  }
});

/// Fetches all unresolved fault reports across every elevator.
final activeFaultsProvider = FutureProvider<List<FaultReportModel>>((
  ref,
) async {
  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  if (!isOnline) {
    final cached = cache.loadActiveFaults();
    return _applyPendingModifications(ref, cached, activeOnly: true);
  }

  try {
    final repo = ref.watch(faultRepositoryProvider);
    final data = await repo.getAllActiveFaults();
    unawaited(cache.saveActiveFaults(data));
    return _applyPendingModifications(ref, data, activeOnly: true);
  } catch (e) {
    final cached = cache.loadActiveFaults().cast<FaultReportModel>();
    if (cached.isNotEmpty) {
      return _applyPendingModifications(ref, cached, activeOnly: true);
    }
    rethrow;
  }
});

/// Fetches all fault reports for a given elevator [id].
final faultsByElevatorProvider =
    FutureProvider.family<List<FaultReportModel>, String>((
      ref,
      elevatorId,
    ) async {
      final isOnline = ref.watch(isOnlineProvider);
      final cache = ref.read(readCacheServiceProvider);

      if (!isOnline) {
        final cached = cache.loadFaultsByElevatorId(elevatorId);
        return _applyPendingModifications(ref, cached, elevatorId: elevatorId);
      }

      try {
        final repo = ref.watch(faultRepositoryProvider);
        final data = await repo.getFaultsByElevatorId(elevatorId);
        return _applyPendingModifications(ref, data, elevatorId: elevatorId);
      } catch (e) {
        final cached = cache.loadFaultsByElevatorId(elevatorId);
        if (cached.isNotEmpty) {
          return _applyPendingModifications(
            ref,
            cached,
            elevatorId: elevatorId,
          );
        }
        rethrow;
      }
    });

/// Fetches a single fault report by its [id].
///
/// Usage: `ref.watch(faultByIdProvider('some-uuid'))`
final faultByIdProvider = FutureProvider.autoDispose
    .family<FaultReportModel, String>((ref, faultId) async {
      final isOnline = ref.watch(isOnlineProvider);
      final cache = ref.read(readCacheServiceProvider);

      if (!isOnline) {
        final cached = cache.loadFaultById(faultId);
        if (cached != null) {
          final res = _applyPendingModifications(ref, [cached]);
          if (res.isNotEmpty) return res.first;
        } else {
          // It might be a purely offline queued item not in cache at all
          final res = _applyPendingModifications(ref, []);
          final found = res.where((f) => f.id == faultId);
          if (found.isNotEmpty) return found.first;
        }
        throw StateError('Arıza detayına ulaşılamıyor (çevrimdışı)');
      }

      try {
        final repo = ref.watch(faultRepositoryProvider);
        final data = await repo.getFaultById(faultId);
        final res = _applyPendingModifications(ref, [data]);
        if (res.isNotEmpty) return res.first;
        return data;
      } catch (e) {
        final cached = cache.loadFaultById(faultId);
        if (cached != null) {
          final res = _applyPendingModifications(ref, [cached]);
          if (res.isNotEmpty) return res.first;
        } else {
          final res = _applyPendingModifications(ref, []);
          final found = res.where((f) => f.id == faultId);
          if (found.isNotEmpty) return found.first;
        }
        rethrow;
      }
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

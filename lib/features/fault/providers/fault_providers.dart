import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/services/sync_queue_service.dart';
import '../models/fault_report_model.dart';
import '../repositories/fault_repository.dart';

// ── Repository ──────────────────────────────────────────────────────────────

/// Provides the [FaultRepository] backed by the live Supabase client.
final faultRepositoryProvider = Provider<FaultRepository>((ref) {
  return FaultRepository(Supabase.instance.client);
});

// ── Data Providers ───────────────────────────────────────────────────────────

/// Fetches all unresolved fault reports across every elevator.
final activeFaultsProvider = FutureProvider<List<FaultReportModel>>((
  ref,
) async {
  final repo = ref.watch(faultRepositoryProvider);
  return repo.getAllActiveFaults();
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
class FaultController extends AsyncNotifier<FaultReportModel?> {
  @override
  Future<FaultReportModel?> build() async => null;

  Future<void> reportFault({
    required String elevatorId,
    required String description,
    String? photoUrl,
  }) async {
    state = const AsyncLoading();

    final isOnline = ref.read(isOnlineProvider);

    if (!isOnline) {
      // ── Offline path ──────────────────────────────────────────────────────
      // Note: photo uploads require connectivity and cannot be queued.
      await ref
          .read(syncQueueServiceProvider)
          .enqueue(
            type: SyncItemType.faultReport,
            payload: {
              'elevator_id': elevatorId,
              'description': description,
              'is_resolved': false,
              'reported_at': DateTime.now().toUtc().toIso8601String(),
              // photo_url intentionally omitted – upload requires network
            },
          );

      state = AsyncData(
        FaultReportModel(
          id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
          elevatorId: elevatorId,
          description: description,
          isResolved: false,
          reportedAt: DateTime.now(),
          isOfflineQueued: true,
        ),
      );
      return;
    }

    // ── Online path ───────────────────────────────────────────────────────
    state = await AsyncValue.guard(() {
      return ref
          .read(faultRepositoryProvider)
          .reportFault(
            elevatorId: elevatorId,
            description: description,
            photoUrl: photoUrl,
          );
    });

    if (!state.hasError) {
      ref.invalidate(activeFaultsProvider);
    }
  }
}

final faultControllerProvider =
    AsyncNotifierProvider<FaultController, FaultReportModel?>(
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

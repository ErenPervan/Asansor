import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/storage_service.dart';
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
final activeFaultsProvider =
    FutureProvider<List<FaultReportModel>>((ref) async {
  final repo = ref.watch(faultRepositoryProvider);
  return repo.getAllActiveFaults();
});

/// Fetches all fault reports for a given elevator [id].
final faultsByElevatorProvider =
    FutureProvider.family<List<FaultReportModel>, String>(
        (ref, elevatorId) async {
  final repo = ref.watch(faultRepositoryProvider);
  return repo.getFaultsByElevatorId(elevatorId);
});

/// Fetches a single fault report by its [id].
///
/// Usage: `ref.watch(faultByIdProvider('some-uuid'))`
final faultByIdProvider =
    FutureProvider.autoDispose.family<FaultReportModel, String>(
  (ref, faultId) async {
    final repo = ref.watch(faultRepositoryProvider);
    return repo.getFaultById(faultId);
  },
);

// ── Report Notifier ──────────────────────────────────────────────────────────

/// Holds the state of an in-flight fault report submission.
class FaultController extends AsyncNotifier<FaultReportModel?> {
  @override
  Future<FaultReportModel?> build() async => null;

  Future<void> reportFault({
    required String elevatorId,
    required String description,
    File? imageFile,
    String? faultType,
    String? priority,
  }) async {
    state = const AsyncLoading();

    final isOnline = ref.read(isOnlineProvider);

    if (!isOnline) {
      final payload = <String, dynamic>{
        'elevator_id': elevatorId,
        'description': description,
        'is_resolved': false,
        'reported_at': DateTime.now().toUtc().toIso8601String(),
        'fault_type': faultType,
        'priority': priority,
      };

      final localMediaPaths = <String>[];
      if (imageFile != null) {
        localMediaPaths.add(imageFile.path);
        payload['_media_fields'] = const ['photo_url'];
        payload['_media_bucket'] = 'fault-images';
      }

      // ── Offline path ──────────────────────────────────────────────────────
      await ref.read(syncQueueServiceProvider).enqueue(
        endpoint: SyncEndpoint.insertFaultReport,
        payload: payload,
        localMediaPaths: localMediaPaths,
      );

      state = AsyncData(
        FaultReportModel(
          id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
          elevatorId: elevatorId,
          description: description,
          isResolved: false,
          reportedAt: DateTime.now(),
          isOfflineQueued: true,
          faultType: faultType,
          priority: priority,
        ),
      );
      return;
    }

    // ── Online path ───────────────────────────────────────────────────────
    state = await AsyncValue.guard(() async {
      String? uploadedPhotoUrl;
      
      if (imageFile != null) {
        uploadedPhotoUrl = await ref.read(storageServiceProvider).uploadImage(
          imageFile,
          'faults',
        );
      }

      return ref.read(faultRepositoryProvider).reportFault(
            elevatorId: elevatorId,
            description: description,
            photoUrl: uploadedPhotoUrl,
            faultType: faultType,
            priority: priority,
          );
    });

    if (!state.hasError && state.value != null) {
      ref.invalidate(activeFaultsProvider);
      
      // Notify all admins that a new fault has been reported.
      final reportedFault = state.value!;
      NotificationService.instance.notifyAllAdmins(
        client: Supabase.instance.client,
        title: 'Yeni Arıza Bildirimi',
        body: reportedFault.description,
        data: {
          'type': 'fault_reported',
          'fault_id': reportedFault.id,
          'elevator_id': reportedFault.elevatorId,
          'route': '/fault/${reportedFault.id}',
        },
      );
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

  Future<bool> resolve(
    String faultId, {
    String? resolutionNotes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(faultRepositoryProvider).resolveFault(
            faultId,
            resolutionNotes: resolutionNotes,
          );
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

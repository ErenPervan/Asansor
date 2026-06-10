import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/core/services/sync_queue_service.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import 'package:asansor/features/maintenance/repositories/maintenance_repository.dart';

Future<String?> copyToDocumentsDirectory(String? path) async {
  if (path == null) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;

  final file = File(path);
  if (!await file.exists()) return null;

  final docsDir = await getApplicationDocumentsDirectory();
  final offlineDir = Directory('${docsDir.path}/offline_media');
  if (!await offlineDir.exists()) await offlineDir.create(recursive: true);

  final fileName =
      '${DateTime.now().millisecondsSinceEpoch}_${p.basename(path)}';
  final dest = File('${offlineDir.path}/$fileName');
  await file.copy(dest.path);
  return dest.path;
}

// ── Repository ──────────────────────────────────────────────────────────────

/// Provides the [MaintenanceRepository] backed by the live Supabase client.
final maintenanceRepositoryProvider = Provider<IMaintenanceRepository>((ref) {
  return MaintenanceRepository(ref.watch(supabaseClientProvider));
});

// ── Data Providers ───────────────────────────────────────────────────────────

/// Fetches all pending (unapproved) maintenance logs across every elevator.
///
/// Used by the dashboard to populate the "Günlük Bakımlar" section.
final pendingMaintenanceProvider = FutureProvider<List<MaintenanceLogModel>>((
  ref,
) async {
  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  // ── Offline path ───────────────────────────────────────────────────────────
  if (!isOnline) {
    return cache.loadPendingMaintenance();
  }

  // ── Online path ────────────────────────────────────────────────────────────
  try {
    final repo = ref.watch(maintenanceRepositoryProvider);
    final data = await repo.getAllPendingLogs();
    // Update the cache in the background — don't await so the UI isn't blocked.
    unawaited(cache.savePendingMaintenance(data));
    return data;
  } catch (e) {
    // Network or Supabase error: serve stale cache so the screen doesn't crash.
    final cached = cache.loadPendingMaintenance();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});

/// Returns the count of maintenance logs completed (approved) today.
final completedTodayCountProvider = FutureProvider<int>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  // ── Offline path ───────────────────────────────────────────────────────────
  if (!isOnline) {
    return cache.loadCompletedTodayCount();
  }

  // ── Online path ────────────────────────────────────────────────────────────
  try {
    final repo = ref.watch(maintenanceRepositoryProvider);
    final count = await repo.getCompletedTodayCount();
    // Update the cache in the background — don't await so the UI isn't blocked.
    unawaited(cache.saveCompletedTodayCount(count));
    return count;
  } catch (e) {
    // Network or Supabase error: serve stale cache so the screen doesn't crash.
    return cache.loadCompletedTodayCount();
  }
});

/// Fetches all maintenance logs for a given elevator [id].
///
/// Usage: `ref.watch(logsByElevatorProvider('some-uuid'))`
final logsByElevatorProvider =
    FutureProvider.family<List<MaintenanceLogModel>, String>((
      ref,
      elevatorId,
    ) async {
      final isOnline = ref.watch(isOnlineProvider);
      final cache = ref.read(readCacheServiceProvider);

      if (!isOnline) {
        return cache.loadPastLogs(elevatorId).cast<MaintenanceLogModel>();
      }

      try {
        final repo = ref.watch(maintenanceRepositoryProvider);
        final data = await repo.getLogsByElevatorId(elevatorId);
        await cache.savePastLogs(elevatorId, data);
        return data;
      } catch (e) {
        final cached = cache
            .loadPastLogs(elevatorId)
            .cast<MaintenanceLogModel>();
        if (cached.isNotEmpty) return cached;
        rethrow;
      }
    });

// ── Action Notifier ──────────────────────────────────────────────────────────

/// Holds the state of an in-flight maintenance log submission.
///
/// Call [MaintenanceController.addLog] to submit.
class MaintenanceController extends AsyncNotifier<MaintenanceLogModel?> {
  @override
  Future<MaintenanceLogModel?> build() async => null;

  // `_uploadPhotos` was removed in favor of queue-first sync.

  Future<void> _enqueueOfflineLog({
    required String elevatorId,
    required String technicianId,
    required String notes,
    required DateTime maintenanceDate,
    Map<String, dynamic>? checklist,
    List<String>? photos,
    String? signaturePath,
    String? customerSignaturePath,
  }) async {
    final stablePhotos = await Future.wait(
      (photos ?? []).map((path) => copyToDocumentsDirectory(path)),
    );
    final stableSignature = await copyToDocumentsDirectory(signaturePath);
    final stableCustomerSignature = await copyToDocumentsDirectory(
      customerSignaturePath,
    );

    final payload = <String, dynamic>{
      'elevator_id': elevatorId,
      'technician_id': technicianId,
      'notes': notes,
      'is_approved': false,
      'maintenance_date': maintenanceDate.toIso8601String(),
      'checklist': ?checklist,
      if (stablePhotos.isNotEmpty)
        'photos': stablePhotos.whereType<String>().toList(),
      'signature_url': ?stableSignature,
      'customer_signature_url': ?stableCustomerSignature,
    };

    await ref
        .read(syncQueueServiceProvider)
        .enqueue(type: SyncItemType.maintenanceLog, payload: payload);

    // Represent success with a synthetic in-memory model so the UI can
    // show a "saved offline" confirmation without a null-state guard.
    state = AsyncData(
      MaintenanceLogModel(
        id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
        elevatorId: elevatorId,
        technicianId: technicianId,
        notes: notes,
        isApproved: false,
        maintenanceDate: maintenanceDate,
        checklist: checklist,
        photos: photos,
        signatureUrl: signaturePath,
        customerSignatureUrl: customerSignaturePath,
        isOfflineQueued: true,
      ),
    );
  }

  Future<void> addLog({
    required String elevatorId,
    required String technicianId,
    required String notes,
    required DateTime maintenanceDate,
    Map<String, dynamic>? checklist,
    List<String>? photos,
    String? signaturePath,
    String? customerSignaturePath,
  }) async {
    state = const AsyncLoading();

    final isOnline = ref.read(isOnlineProvider);

    await _enqueueOfflineLog(
      elevatorId: elevatorId,
      technicianId: technicianId,
      notes: notes,
      maintenanceDate: maintenanceDate,
      checklist: checklist,
      photos: photos,
      signaturePath: signaturePath,
      customerSignaturePath: customerSignaturePath,
    );

    if (isOnline) {
      // Offline queue will handle photo uploads, insertion, PDF generation,
      // schedule completion, and notifications during flush.
      await ref
          .read(syncQueueServiceProvider)
          .flush(ref.read(supabaseClientProvider));

      // We don't check for errors here because flush swallows them,
      // but if it failed, it stays in the queue. We just invalidate.
      ref.invalidate(pendingMaintenanceProvider);
      ref.invalidate(completedTodayCountProvider);
      ref.invalidate(logsByElevatorProvider(elevatorId));
    }
  }
}

final maintenanceControllerProvider =
    AsyncNotifierProvider<MaintenanceController, MaintenanceLogModel?>(
      MaintenanceController.new,
    );

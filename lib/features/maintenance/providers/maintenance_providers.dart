import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/core/services/notification_service.dart';
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
  final queueService = ref.watch(syncQueueServiceProvider);
  final pendingPayloads = queueService.pendingItemsOfType(SyncItemType.maintenanceLog);
  final pendingLogs = pendingPayloads.map((p) {
    p['id'] = 'pending_${p['idempotency_key']}';
    return MaintenanceLogModel.fromOfflineQueue(p);
  }).where((l) => !l.isApproved).toList();

  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  List<MaintenanceLogModel> remoteLogs = [];
  if (!isOnline) {
    remoteLogs = cache.loadPendingMaintenance();
  } else {
    try {
      final repo = ref.watch(maintenanceRepositoryProvider);
      remoteLogs = await repo.getAllPendingLogs();
      unawaited(cache.savePendingMaintenance(remoteLogs));
    } catch (e) {
      remoteLogs = cache.loadPendingMaintenance();
      if (remoteLogs.isEmpty) rethrow;
    }
  }

  return [...pendingLogs, ...remoteLogs];
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
      final queueService = ref.watch(syncQueueServiceProvider);
      final pendingPayloads = queueService.pendingItemsOfType(SyncItemType.maintenanceLog);
      final pendingLogs = pendingPayloads
          .where((p) => p['elevator_id'] == elevatorId)
          .map((p) {
            p['id'] = 'pending_${p['idempotency_key']}';
            return MaintenanceLogModel.fromOfflineQueue(p);
          }).toList();

      final isOnline = ref.watch(isOnlineProvider);
      final cache = ref.read(readCacheServiceProvider);

      List<MaintenanceLogModel> remoteLogs = [];
      if (!isOnline) {
        remoteLogs = cache.loadPastLogs(elevatorId).cast<MaintenanceLogModel>();
      } else {
        try {
          final repo = ref.watch(maintenanceRepositoryProvider);
          remoteLogs = await repo.getLogsByElevatorId(elevatorId);
          await cache.savePastLogs(elevatorId, remoteLogs);
        } catch (e) {
          remoteLogs = cache.loadPastLogs(elevatorId).cast<MaintenanceLogModel>();
          if (remoteLogs.isEmpty) rethrow;
        }
      }

      return [...pendingLogs, ...remoteLogs];
    });

// ── Action Notifier ──────────────────────────────────────────────────────────

/// Holds the state of an in-flight maintenance log submission.
///
/// Call [MaintenanceController.addLog] to submit.
class MaintenanceController extends AsyncNotifier<MaintenanceLogModel?> {
  @override
  Future<MaintenanceLogModel?> build() async => null;

  // Inline photo upload removed in favor of SyncQueueService's background queue handling.

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
      'idempotency_key': const Uuid().v4(),
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
      // Background flush; errors are handled silently by the queue service.
      await ref.read(syncQueueServiceProvider).flush(ref.read(supabaseClientProvider));
      
      // Notify all admins optimistically
      await NotificationService.instance.notifyAllAdmins(
        client: ref.read(supabaseClientProvider),
        title: 'Bakım Tamamlandı',
        body: 'Bir teknisyen bakım görevini tamamladı.',
        data: {
          'type': 'task_completed',
          'route': '/admin/master-calendar',
          'elevator_id': elevatorId,
        },
      );
    }
  }
}

final maintenanceControllerProvider =
    AsyncNotifierProvider<MaintenanceController, MaintenanceLogModel?>(
      MaintenanceController.new,
    );



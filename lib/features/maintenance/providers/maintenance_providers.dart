import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sync_queue_service.dart';
import '../models/maintenance_log_model.dart';
import '../repositories/maintenance_repository.dart';
import '../../admin/repositories/schedule_repository.dart';

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
final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository(Supabase.instance.client);
});

// ── Data Providers ───────────────────────────────────────────────────────────

/// Fetches all pending (unapproved) maintenance logs across every elevator.
///
/// Used by the dashboard to populate the "Günlük Bakımlar" section.
final pendingMaintenanceProvider = FutureProvider<List<MaintenanceLogModel>>((
  ref,
) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return repo.getAllPendingLogs();
});

/// Returns the count of maintenance logs completed (approved) today.
final completedTodayCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return repo.getCompletedTodayCount();
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
        return cache
            .loadPastLogs(elevatorId, MaintenanceLogModel.fromJson)
            .cast<MaintenanceLogModel>();
      }

      try {
        final repo = ref.watch(maintenanceRepositoryProvider);
        final data = await repo.getLogsByElevatorId(elevatorId);
        await cache.savePastLogs(elevatorId, data);
        return data;
      } catch (e) {
        final cached = cache
            .loadPastLogs(elevatorId, MaintenanceLogModel.fromJson)
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

  Future<List<String>> _uploadPhotos({
    required SupabaseClient client,
    required List<String> photoPaths,
    required String elevatorId,
    required String technicianId,
  }) async {
    final storage = client.storage.from(_maintenancePhotosBucket);
    final uploadedUrls = <String>[];
    var index = 0;

    for (final path in photoPaths) {
      if (_isRemoteUrl(path)) {
        uploadedUrls.add(path);
        continue;
      }

      final file = File(path);
      if (!await file.exists()) {
        continue;
      }

      final extension = _safeExtension(path);
      final fileName =
          'maintenance_logs/$elevatorId/${technicianId}_${DateTime.now().millisecondsSinceEpoch}_$index.$extension';
      index++;

      await storage.upload(fileName, file);
      uploadedUrls.add(storage.getPublicUrl(fileName));
    }

    return uploadedUrls;
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

    if (!isOnline) {
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
      return;
    }

    List<String>? photoUrls;
    String? sigUrlStr;
    String? custSigUrlStr;

    try {
      if (photos != null && photos.isNotEmpty) {
        photoUrls = await _uploadPhotos(
          client: Supabase.instance.client,
          photoPaths: photos,
          elevatorId: elevatorId,
          technicianId: technicianId,
        );
      }
      if (signaturePath != null) {
        final res = await _uploadPhotos(
          client: Supabase.instance.client,
          photoPaths: [signaturePath],
          elevatorId: elevatorId,
          technicianId: technicianId,
        );
        if (res.isNotEmpty) sigUrlStr = res.first;
      }
      if (customerSignaturePath != null) {
        final res = await _uploadPhotos(
          client: Supabase.instance.client,
          photoPaths: [customerSignaturePath],
          elevatorId: elevatorId,
          technicianId: technicianId,
        );
        if (res.isNotEmpty) custSigUrlStr = res.first;
      }
    } catch (e) {
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
      return;
    }

    // ── Online path: write directly to Supabase ───────────────────────────
    state = await AsyncValue.guard(() {
      return ref
          .read(maintenanceRepositoryProvider)
          .addLog(
            elevatorId: elevatorId,
            technicianId: technicianId,
            notes: notes,
            maintenanceDate: maintenanceDate,
            checklist: checklist,
            photos: photoUrls,
            signatureUrl: sigUrlStr,
            customerSignatureUrl: custSigUrlStr,
          );
    });

    // After a successful log, auto-complete any matching scheduled task
    // for the same elevator+technician on today's date.
    if (!state.hasError && state.value != null) {
      await ScheduleRepository(
        Supabase.instance.client,
      ).completeMatchingSchedule(
        elevatorId: elevatorId,
        technicianId: technicianId,
      );

      // Notify all admins that a maintenance job has been completed.
      await NotificationService.instance.notifyAllAdmins(
        client: Supabase.instance.client,
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

const _maintenancePhotosBucket = 'maintenance-photos';

bool _isRemoteUrl(String path) {
  return path.startsWith('http://') || path.startsWith('https://');
}

String _safeExtension(String path) {
  final dotIndex = path.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == path.length - 1) {
    return 'jpg';
  }

  final extension = path.substring(dotIndex + 1).toLowerCase();
  if (extension.length > 5) {
    return 'jpg';
  }

  return extension;
}

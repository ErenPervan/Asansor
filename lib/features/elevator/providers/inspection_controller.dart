import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/services/sync_queue_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/inspection_history_model.dart';
import 'elevator_providers.dart';

final inspectionControllerProvider = StateNotifierProvider.family<
    InspectionController,
    AsyncValue<List<InspectionHistoryModel>>, String>(
  (ref, elevatorId) => InspectionController(ref, elevatorId),
);

class InspectionController extends StateNotifier<
    AsyncValue<List<InspectionHistoryModel>>> {
  InspectionController(this.ref, this.elevatorId)
      : super(const AsyncLoading()) {
    unawaited(loadHistory());
  }

  final Ref ref;
  final String elevatorId;

  Future<List<InspectionHistoryModel>> _fetchHistory(String elevatorId) async {
    final repository = ref.read(elevatorRepositoryProvider);
    return repository.getInspectionHistory(elevatorId);
  }

  Future<void> loadHistory() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchHistory(elevatorId));
  }

  /// Adds a new inspection record.
  /// If offline, adds to the sync queue.
  Future<void> addInspection({
    required DateTime inspectionDate,
    required String status,
    String? inspectorName,
    String? notes,
  }) async {
    state = const AsyncLoading();
    
    try {
      final user = ref.read(authControllerProvider).valueOrNull;
      if (user == null) throw Exception('User not authenticated');

      final isOnline = ref.read(isOnlineProvider);
      final syncQueue = ref.read(syncQueueServiceProvider);
      final repository = ref.read(elevatorRepositoryProvider);

      // Default next inspection is 1 year from now.
      final nextInspectionDate = DateTime(
        inspectionDate.year + 1,
        inspectionDate.month,
        inspectionDate.day,
      );

      if (isOnline) {
        await repository.addInspection(
          elevatorId: elevatorId,
          technicianId: user.id,
          inspectionDate: inspectionDate,
          status: status,
          inspectorName: inspectorName,
          notes: notes,
          nextInspectionDate: nextInspectionDate,
        );
      } else {
        // Enqueue for offline sync
        await syncQueue.enqueue(
          endpoint: SyncEndpoint.insertInspectionUpdate,
          payload: {
            'elevator_id': elevatorId,
            'technician_id': user.id,
            'inspection_date': inspectionDate.toUtc().toIso8601String(),
            'status': status,
            'inspector_name': inspectorName,
            'notes': notes,
            'next_inspection_date': nextInspectionDate.toUtc().toIso8601String(),
          },
        );
      }

      // Refresh the local elevator state so the UI reflects the new status
      ref.invalidate(elevatorsProvider);

      // Refresh the history
      await loadHistory();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';
final customerElevatorProvider = FutureProvider.autoDispose<ElevatorModel?>((
  ref,
) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final elevatorId = profile?.elevatorId;

  if (elevatorId == null || elevatorId.isEmpty) {
    return null;
  }

  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  if (!isOnline) {
    final cachedElevators = cache.loadElevators();
    return cachedElevators.where((e) => e.id == elevatorId).firstOrNull;
  }

  try {
    final response = await ref.read(supabaseClientProvider)
        .from('elevators')
        .select()
        .eq('id', elevatorId)
        .maybeSingle();

    if (response == null) return null;
    final model = ElevatorModel.fromJson(response);
    
    final existing = cache.loadElevators();
    final updated = existing.where((e) => e.id != elevatorId).toList()..add(model);
    await cache.saveElevators(updated);

    return model;
  } catch (e) {
    final cachedElevators = cache.loadElevators();
    return cachedElevators.where((e) => e.id == elevatorId).firstOrNull;
  }
});

final customerMaintenanceLogsProvider =
    FutureProvider.autoDispose<List<MaintenanceLogModel>>((ref) async {
      final profile = await ref.watch(currentProfileProvider.future);
      final elevatorId = profile?.elevatorId;

      if (elevatorId == null || elevatorId.isEmpty) {
        return [];
      }

      final isOnline = ref.watch(isOnlineProvider);
      final cache = ref.read(readCacheServiceProvider);

      if (!isOnline) {
        return cache.loadPastLogs(elevatorId);
      }

      try {
        final response = await ref.read(supabaseClientProvider)
            .from('maintenance_logs')
            .select()
            .eq('elevator_id', elevatorId)
            .order('maintenance_date', ascending: false)
            .limit(10);

        final logs = response
            .map((json) => MaintenanceLogModel.fromJson(json))
            .toList();

        await cache.savePastLogs(elevatorId, logs);

        return logs;
      } catch (e) {
        return cache.loadPastLogs(elevatorId);
      }
    });

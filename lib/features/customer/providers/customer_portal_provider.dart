import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';

final customerElevatorProvider = FutureProvider.autoDispose<ElevatorModel?>((
  ref,
) async {
  // Get the customer's specific elevator ID from their profile
  final profile = await ref.watch(currentProfileProvider.future);
  final elevatorId = profile?.elevatorId;

  if (elevatorId == null || elevatorId.isEmpty) {
    return null; // The user has no assigned elevator
  }

  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  if (!isOnline) {
    final cached = cache.loadElevators();
    for (final e in cached) {
      if (e.id == elevatorId) return e;
    }
    return null;
  }

  try {
    // Fetch the specific elevator
    final response = await ref
        .read(supabaseClientProvider)
        .from('elevators')
        .select()
        .eq('id', elevatorId)
        .maybeSingle();

    if (response == null) return null;
    final elevator = ElevatorModel.fromJson(response);

    final existingCache = cache.loadElevators();
    final index = existingCache.indexWhere((e) => e.id == elevator.id);
    if (index >= 0) {
      existingCache[index] = elevator;
    } else {
      existingCache.add(elevator);
    }
    unawaited(cache.saveElevators(existingCache));

    return elevator;
  } catch (e) {
    final cached = cache.loadElevators();
    for (final ev in cached) {
      if (ev.id == elevatorId) return ev;
    }
    return null;
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
        return cache.loadPastLogs(elevatorId).cast<MaintenanceLogModel>();
      }

      try {
        // Fetch recent maintenance logs for this elevator
        final response = await ref
            .read(supabaseClientProvider)
            .from('maintenance_logs')
            .select()
            .eq('elevator_id', elevatorId)
            .order('maintenance_date', ascending: false)
            .limit(10);

        final logs = response
            .map((json) => MaintenanceLogModel.fromJson(json))
            .toList();

        unawaited(cache.savePastLogs(elevatorId, logs));
        return logs;
      } catch (e) {
        return cache.loadPastLogs(elevatorId).cast<MaintenanceLogModel>();
      }
    });

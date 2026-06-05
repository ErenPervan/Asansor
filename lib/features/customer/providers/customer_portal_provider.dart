import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';

final customerElevatorProvider = FutureProvider.autoDispose<ElevatorModel?>((
  ref,
) async {
  // Get the customer's specific elevator ID from their profile
  final profile = await ref.watch(currentProfileProvider.future);
  final elevatorId = profile?.elevatorId;

  if (elevatorId == null || elevatorId.isEmpty) {
    return null; // The user has no assigned elevator
  }

  // Fetch the specific elevator
  final response = await Supabase.instance.client
      .from('elevators')
      .select()
      .eq('id', elevatorId)
      .maybeSingle();

  if (response == null) return null;
  return ElevatorModel.fromJson(response);
});

final customerMaintenanceLogsProvider =
    FutureProvider.autoDispose<List<MaintenanceLogModel>>((ref) async {
      final profile = await ref.watch(currentProfileProvider.future);
      final elevatorId = profile?.elevatorId;

      if (elevatorId == null || elevatorId.isEmpty) {
        return [];
      }

      // Fetch recent maintenance logs for this elevator
      final response = await Supabase.instance.client
          .from('maintenance_logs')
          .select()
          .eq('elevator_id', elevatorId)
          .order('maintenance_date', ascending: false)
          .limit(10);

      return response
          .map((json) => MaintenanceLogModel.fromJson(json))
          .toList();
    });

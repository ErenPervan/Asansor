import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/elevator_model.dart';
import '../repositories/elevator_repository.dart';

// ── Repository ──────────────────────────────────────────────────────────────

/// Provides the [ElevatorRepository] backed by the live Supabase client.
final elevatorRepositoryProvider = Provider<ElevatorRepository>((ref) {
  return ElevatorRepository(Supabase.instance.client);
});

// ── Data Providers ───────────────────────────────────────────────────────────

/// Fetches the full list of elevators from Supabase.
///
/// Re-fetch by calling `ref.invalidate(elevatorsProvider)`.
final elevatorsProvider = FutureProvider<List<ElevatorModel>>((ref) async {
  final repo = ref.watch(elevatorRepositoryProvider);
  return repo.getAllElevators();
});

/// Fetches a single elevator by [id].
///
/// Usage: `ref.watch(elevatorByIdProvider('some-uuid'))`
final elevatorByIdProvider =
    FutureProvider.family<ElevatorModel, String>((ref, id) async {
  final repo = ref.watch(elevatorRepositoryProvider);
  return repo.getElevatorById(id);
});

// ── Create notifier ──────────────────────────────────────────────────────────

/// Handles the "Add Elevator" form submission.
///
/// On success the state holds the newly created [ElevatorModel].
/// Callers should watch [elevatorCreateControllerProvider] to read the result
/// and navigate to the QR view.
class ElevatorCreateController
    extends AutoDisposeAsyncNotifier<ElevatorModel?> {
  @override
  Future<ElevatorModel?> build() async => null;

  Future<void> create({
    required String buildingName,
    String? address,
    String status = 'active',
    double? latitude,
    double? longitude,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final elevator =
          await ref.read(elevatorRepositoryProvider).createElevator(
                buildingName: buildingName,
                address: address,
                status: status,
                latitude: latitude,
                longitude: longitude,
              );
      // Refresh the global elevator list so dashboards stay in sync.
      ref.invalidate(elevatorsProvider);
      return elevator;
    });
  }
}

final elevatorCreateControllerProvider = AutoDisposeAsyncNotifierProvider<
    ElevatorCreateController, ElevatorModel?>(
  ElevatorCreateController.new,
);

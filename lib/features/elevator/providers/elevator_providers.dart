import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../models/elevator_model.dart';
import '../repositories/elevator_repository.dart';

// ── Repository ──────────────────────────────────────────────────────────────

/// Provides the [ElevatorRepository] backed by the live Supabase client.
final elevatorRepositoryProvider = Provider<ElevatorRepository>((ref) {
  return ElevatorRepository(Supabase.instance.client);
});

// ── Fault / Telemetry / Schedule Providers ───────────────────────────────────

/// Returns the [DateTime] of the most recent fault report for this elevator,
/// or `null` when no fault reports exist yet.
///
/// Queries `fault_reports.reported_at` (the timestamp written at fault
/// creation time) ordered descending and takes only the first row.
///
/// Usage: `ref.watch(latestFaultDateProvider('some-uuid'))`
final latestFaultDateProvider = FutureProvider.family<DateTime?, String>((
  ref,
  elevatorId,
) async {
  if (!ref.watch(isOnlineProvider)) return null;

  final client = Supabase.instance.client;
  final response = await client
      .from('fault_reports')
      .select('reported_at')
      .eq('elevator_id', elevatorId)
      .order('reported_at', ascending: false)
      .limit(1);

  final rows = response as List<dynamic>;
  if (rows.isEmpty) return null;

  final raw = rows.first['reported_at'] as String?;
  if (raw == null) return null;
  return DateTime.parse(raw);
});

/// Returns the [DateTime] of the closest upcoming (pending) scheduled
/// maintenance for this elevator, or `null` when none is scheduled.
///
/// Queries `maintenance_schedules.scheduled_date` where:
///  - `elevator_id` matches
///  - `status = 'pending'`
///  - `scheduled_date` is in the future
///
/// Results are ordered ascending so the first row is the next appointment.
///
/// Usage: `ref.watch(nextScheduledMaintenanceProvider('some-uuid'))`
final nextScheduledMaintenanceProvider =
    FutureProvider.family<DateTime?, String>((ref, elevatorId) async {
      if (!ref.watch(isOnlineProvider)) return null;

      final client = Supabase.instance.client;
      final now = DateTime.now().toUtc().toIso8601String();

      final response = await client
          .from('maintenance_schedules')
          .select('scheduled_date')
          .eq('elevator_id', elevatorId)
          .eq('status', 'pending')
          .gte('scheduled_date', now)
          .order('scheduled_date', ascending: true)
          .limit(1);

      final rows = response as List<dynamic>;
      if (rows.isEmpty) return null;

      final raw = rows.first['scheduled_date'] as String?;
      if (raw == null) return null;
      return DateTime.parse(raw);
    });

// ── Data Providers ───────────────────────────────────────────────────────────

/// Fetches the full list of elevators from Supabase.
///
/// Caching behaviour:
/// - **Online**  : fetches fresh data → persists to `elevators_cache` → returns it.
/// - **Offline** : skips the network call and returns the last cached snapshot.
/// - **Network error while "online"** : falls back to cache; rethrows only when
///   the cache is also empty (true first-time-offline with no prior data).
///
/// Re-fetch by calling `ref.invalidate(elevatorsProvider)`.
final elevatorsProvider = FutureProvider<List<ElevatorModel>>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  // ── Offline path ───────────────────────────────────────────────────────────
  if (!isOnline) {
    return cache.loadElevators();
  }

  // ── Online path ────────────────────────────────────────────────────────────
  try {
    final repo = ref.watch(elevatorRepositoryProvider);
    final data = await repo.getAllElevators();
    // Update the cache in the background — don't await so the UI isn't blocked.
    unawaited(cache.saveElevators(data));
    return data;
  } catch (e) {
    // Network or Supabase error: serve stale cache so the screen doesn't crash.
    final cached = cache.loadElevators();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});

/// Fetches a single elevator by [id].
///
/// Usage: `ref.watch(elevatorByIdProvider('some-uuid'))`
final elevatorByIdProvider = FutureProvider.family<ElevatorModel, String>((
  ref,
  id,
) async {
  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  if (!isOnline) {
    final cachedElevators = cache.loadElevators();
    return cachedElevators.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Elevator not found in offline cache.'),
    );
  }

  try {
    final repo = ref.watch(elevatorRepositoryProvider);
    return await repo.getElevatorById(id);
  } catch (e) {
    final cachedElevators = cache.loadElevators();
    final cached = cachedElevators.where((e) => e.id == id).firstOrNull;
    if (cached != null) return cached;
    rethrow;
  }
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
    int? maintenanceDay,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final elevator = await ref
          .read(elevatorRepositoryProvider)
          .createElevator(
            buildingName: buildingName,
            address: address,
            status: status,
            latitude: latitude,
            longitude: longitude,
            maintenanceDay: maintenanceDay,
          );
      // Refresh the global elevator list so dashboards stay in sync.
      ref.invalidate(elevatorsProvider);
      return elevator;
    });
  }
}

final elevatorCreateControllerProvider =
    AutoDisposeAsyncNotifierProvider<ElevatorCreateController, ElevatorModel?>(
      ElevatorCreateController.new,
    );

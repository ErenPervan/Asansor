import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/models/paginated_state.dart';
import '../models/elevator_model.dart';
import '../repositories/elevator_repository.dart';

// ── Repository ──────────────────────────────────────────────────────────────

/// Provides the [ElevatorRepository] backed by the live Supabase client.
final elevatorRepositoryProvider = Provider<ElevatorRepository>((ref) {
  return ElevatorRepository(Supabase.instance.client);
});

// ── Data Providers ───────────────────────────────────────────────────────────

// ── Data Providers ───────────────────────────────────────────────────────────

final elevatorListProvider =
    AsyncNotifierProvider<ElevatorListController, PaginatedState<ElevatorModel>>(
        ElevatorListController.new);

class ElevatorListController extends AsyncNotifier<PaginatedState<ElevatorModel>> {
  static const _pageSize = 20;

  @override
  Future<PaginatedState<ElevatorModel>> build() async {
    final isOnline = ref.watch(isOnlineProvider);
    final cache = ref.read(readCacheServiceProvider);

    if (!isOnline) {
      final cachedItems = cache.loadElevators();
      return PaginatedState(
        items: cachedItems,
        hasMore: false, // Assume we load everything from cache
      );
    }

    try {
      final repo = ref.watch(elevatorRepositoryProvider);
      final items = await repo.getAllElevators(from: 0, to: _pageSize - 1);
      
      // Update cache with first page for now, or handle full sync separately
      // For now, let's just save what we fetched
      cache.saveElevators(items);
      
      return PaginatedState(
        items: items,
        hasMore: items.length == _pageSize,
      );
    } catch (e) {
      final cached = cache.loadElevators();
      if (cached.isNotEmpty) {
        return PaginatedState(items: cached, hasMore: false);
      }
      rethrow;
    }
  }

  Future<void> loadMore() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) return;

    final currentState = state.value;
    if (currentState == null || !currentState.hasMore || currentState.isLoadingMore) {
      return;
    }

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    final nextFrom = currentState.items.length;
    final nextTo = nextFrom + _pageSize - 1;

    try {
      final repo = ref.read(elevatorRepositoryProvider);
      final newItems = await repo.getAllElevators(from: nextFrom, to: nextTo);

      state = AsyncData(currentState.copyWith(
        items: [...currentState.items, ...newItems],
        hasMore: newItems.length == _pageSize,
        isLoadingMore: false,
      ));
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(elevatorRepositoryProvider);
      final items = await repo.getAllElevators(from: 0, to: _pageSize - 1);
      ref.read(readCacheServiceProvider).saveElevators(items);
      return PaginatedState(
        items: items,
        hasMore: items.length == _pageSize,
      );
    });
  }
}

/// Provides all elevators without pagination. 
/// Useful for lookups (ID -> Name) and admin views that need the full set.
final elevatorsProvider = FutureProvider<List<ElevatorModel>>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  if (!isOnline) {
    return cache.loadElevators();
  }

  try {
    final repo = ref.watch(elevatorRepositoryProvider);
    final items = await repo.fetchAllElevators();
    cache.saveElevators(items);
    return items;
  } catch (e) {
    final cached = cache.loadElevators();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
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
    int? maintenanceDay,
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
                maintenanceDay: maintenanceDay,
              );
      // Refresh the global elevator list so dashboards stay in sync.
      ref.invalidate(elevatorListProvider);
      return elevator;
    });
  }
}

final elevatorCreateControllerProvider = AutoDisposeAsyncNotifierProvider<
    ElevatorCreateController, ElevatorModel?>(
  ElevatorCreateController.new,
);

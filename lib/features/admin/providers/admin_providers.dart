import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/services/auto_schedule_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../models/profile_model.dart';
import '../models/schedule_model.dart';
import '../models/schedule_with_details.dart';
import '../models/technician_stats.dart';
import '../repositories/admin_repository.dart';
import '../repositories/schedule_repository.dart';
import 'profile_providers.dart';

// ── Repository providers ──────────────────────────────────────────────────────

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(Supabase.instance.client);
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(Supabase.instance.client);
});

// ── Read providers ────────────────────────────────────────────────────────────

/// Admin KPI stats (total elevators, active faults, monthly completed/pending).
final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) {
  return ref.watch(adminRepositoryProvider).getAdminStats();
});

/// All schedules across all technicians — used on the Admin Calendar/Dashboard.
final allSchedulesProvider =
    FutureProvider.autoDispose<List<ScheduleModel>>((ref) {
  return ref.watch(scheduleRepositoryProvider).getAllSchedules();
});

/// **Pending** schedules for the currently logged-in technician.
final myPendingSchedulesProvider =
    FutureProvider.autoDispose<List<ScheduleModel>>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null) return [];
  return ref
      .watch(scheduleRepositoryProvider)
      .getTechnicianPendingTasks(user.id);
});

/// Real-time stream of **all** (non-cancelled) schedules for the currently
/// logged-in technician. Re-emits whenever Supabase pushes a change.
///
/// Caching behaviour:
/// - **Online**  : streams live data from Supabase Realtime; each emission is
///   written to `tasks_cache` so the data is available when offline later.
/// - **Offline** : skips the Supabase connection and emits the cached snapshot
///   once as a one-shot `Stream.value(...)`.
/// - **Mid-session disconnect** : the `StreamController` catches stream errors
///   and emits the cached snapshot instead of propagating an error to the UI.
///
/// Used by the Technician's Daily Agenda on [HomeView].
final technicianScheduleStreamProvider =
    StreamProvider.autoDispose<List<ScheduleModel>>((ref) {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null) return const Stream.empty();

  final isOnline = ref.read(isOnlineProvider);
  final cache = ref.read(readCacheServiceProvider);

  // ── Offline path ───────────────────────────────────────────────────────────
  if (!isOnline) {
    return Stream.value(cache.loadMyTasks(user.id));
  }

  // ── Online path — proxy stream that also updates the cache ─────────────────
  // A StreamController is used so that mid-session network errors can be
  // converted into a cache-fallback emission rather than crashing the UI.
  final controller = StreamController<List<ScheduleModel>>();

  final subscription = ref
      .read(scheduleRepositoryProvider)
      .getMyTasksStream(user.id)
      .listen(
    (tasks) {
      cache.saveMyTasks(user.id, tasks); // fire-and-forget cache write
      if (!controller.isClosed) controller.add(tasks);
    },
    onError: (_) {
      // Connection lost mid-session: serve stale cache once and stay open
      // so the stream doesn't enter an error state in the UI.
      final cached = cache.loadMyTasks(user.id);
      if (!controller.isClosed) controller.add(cached);
    },
    onDone: () {
      if (!controller.isClosed) controller.close();
    },
    cancelOnError: false,
  );

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

// ── Write / action notifier ───────────────────────────────────────────────────

/// Notifier that wraps the most recent schedule action (assign / update status).
///
/// Consumers call:
/// ```dart
/// ref.read(scheduleControllerProvider.notifier).assignTask(...);
/// ref.read(scheduleControllerProvider.notifier).updateStatus(...);
/// ```
class ScheduleController extends AsyncNotifier<ScheduleModel?> {
  @override
  Future<ScheduleModel?> build() async => null;

  Future<void> assignTask({
    required String elevatorId,
    required String technicianId,
    required DateTime scheduledDate,
    String? notes,
    String priority = 'normal',
  }) async {
    final createdBy =
        ref.read(authControllerProvider).valueOrNull?.id ?? '';
    if (createdBy.isEmpty) {
      state = AsyncError(
        Exception('Oturum açmış kullanıcı bulunamadı.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(scheduleRepositoryProvider).assignTask(
            elevatorId: elevatorId,
            technicianId: technicianId,
            scheduledDate: scheduledDate,
            notes: notes,
            createdBy: createdBy,
            priority: priority,
          ),
    );

    // Refresh related providers so the dashboard stays up to date.
    if (!state.hasError) {
      ref.invalidate(allSchedulesProvider);
      ref.invalidate(adminStatsProvider);
    }
  }

  Future<void> updateStatus({
    required String taskId,
    required String status,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(scheduleRepositoryProvider).updateTaskStatus(
            taskId: taskId,
            status: status,
          ),
    );

    if (!state.hasError) {
      ref.invalidate(allSchedulesProvider);
      ref.invalidate(myPendingSchedulesProvider);
      ref.invalidate(adminStatsProvider);
    }
  }
}

final scheduleControllerProvider =
    AsyncNotifierProvider<ScheduleController, ScheduleModel?>(
  ScheduleController.new,
);

// ── Master Calendar ───────────────────────────────────────────────────────────

/// Immutable filter applied to the Master Calendar.
///
/// Both fields default to `null` (= "show all").
class MasterCalendarFilter {
  const MasterCalendarFilter({this.technicianId, this.status});

  /// When set, only tasks assigned to this technician are shown.
  final String? technicianId;

  /// When set, only tasks with this status are shown
  /// (one of 'pending' | 'in_progress' | 'completed' | 'cancelled').
  final String? status;

  bool get isActive => technicianId != null || status != null;

  MasterCalendarFilter copyWith({
    Object? technicianId = _sentinel,
    Object? status = _sentinel,
  }) {
    return MasterCalendarFilter(
      technicianId: technicianId == _sentinel
          ? this.technicianId
          : technicianId as String?,
      status: status == _sentinel ? this.status : status as String?,
    );
  }
}

// Sentinel for copyWith to distinguish "not provided" from explicit null.
const _sentinel = Object();

class MasterCalendarFilterNotifier
    extends AutoDisposeNotifier<MasterCalendarFilter> {
  @override
  MasterCalendarFilter build() => const MasterCalendarFilter();

  void setTechnician(String? id) =>
      state = state.copyWith(technicianId: id);

  void setStatus(String? s) => state = state.copyWith(status: s);

  void clear() => state = const MasterCalendarFilter();
}

final masterCalendarFilterProvider = AutoDisposeNotifierProvider<
    MasterCalendarFilterNotifier, MasterCalendarFilter>(
  MasterCalendarFilterNotifier.new,
);

/// All [ScheduleWithDetails] records — schedules joined in Dart with elevator
/// and profile tables.  Rebuilt when any of the three source providers change.
final allSchedulesWithDetailsProvider =
    FutureProvider.autoDispose<List<ScheduleWithDetails>>((ref) async {
  // Fetch concurrently.
  final schedulesFuture = ref.watch(allSchedulesProvider.future);
  final elevatorsFuture = ref.watch(elevatorsProvider.future);
  final profilesFuture = ref.watch(allProfilesProvider.future);

  final schedules = await schedulesFuture;
  final elevators = await elevatorsFuture;
  final profiles = await profilesFuture;

  final elevMap = {for (final e in elevators) e.id: e};
  final profMap = {for (final ProfileModel p in profiles) p.id: p};

  return schedules.map((s) {
    final elev = elevMap[s.elevatorId];
    final prof = profMap[s.technicianId];
    // Empty technicianId means the task is auto-generated and not yet
    // assigned to anyone.  Show "Atanmamış" so admins can identify it.
    final techName = s.isUnassigned
        ? 'Atanmamış'
        : (prof?.displayName ?? 'Teknisyen');
    return ScheduleWithDetails(
      schedule: s,
      buildingName: elev?.buildingName ?? 'Asansör',
      address: elev?.address,
      technicianName: techName,
      technicianId: s.technicianId,
    );
  }).toList();
});

// ── Auto-Schedule ─────────────────────────────────────────────────────────────

/// Result value held by [autoScheduleControllerProvider].
///
/// - `null`  → initial / idle state (no run yet)
/// - non-null → result of the last [AutoScheduleController.generate] call
class AutoScheduleState {
  const AutoScheduleState({required this.inserted, required this.skipped});

  final int inserted;
  final int skipped;
}

/// Notifier that runs [AutoScheduleService.generateMonthlyMaintenances] and
/// exposes the result so the UI can show a meaningful Snackbar.
///
/// Usage:
/// ```dart
/// await ref.read(autoScheduleControllerProvider.notifier).generate(month);
/// final state = ref.read(autoScheduleControllerProvider);
/// state.whenData((result) => ...);
/// ```
class AutoScheduleController
    extends AutoDisposeAsyncNotifier<AutoScheduleState?> {
  @override
  Future<AutoScheduleState?> build() async => null;

  Future<void> generate(DateTime targetMonth) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = AutoScheduleService(Supabase.instance.client);
      final result = await service.generateMonthlyMaintenances(targetMonth);

      // Refresh all calendar providers so new tasks appear immediately.
      ref.invalidate(allSchedulesProvider);
      ref.invalidate(adminStatsProvider);

      return AutoScheduleState(
        inserted: result.inserted,
        skipped: result.skipped,
      );
    });
  }
}

final autoScheduleControllerProvider = AutoDisposeAsyncNotifierProvider<
    AutoScheduleController, AutoScheduleState?>(
  AutoScheduleController.new,
);

// ── Technician Management ─────────────────────────────────────────────────────

/// Builds a [TechnicianStats] list for every technician profile.
///
/// For each technician it computes:
/// - Today's tasks (with elevator display info)
/// - Today's completed count
/// - This month's completed count
///
/// All four underlying fetches are started concurrently to minimise latency.
final technicianManagementProvider =
    FutureProvider.autoDispose<List<TechnicianStats>>((ref) async {
  final repo = ref.read(scheduleRepositoryProvider);

  // Start all fetches concurrently.
  final techFuture =
      ref.watch(profilesByRoleProvider('technician').future);
  final elevFuture = ref.watch(elevatorsProvider.future);
  final todayFuture = repo.getTodayAllSchedules();
  final monthFuture = repo.getMonthlyCompletedCountPerTechnician();

  final technicians = await techFuture;
  final elevators = await elevFuture;
  final todaySchedules = await todayFuture;
  final monthlyCount = await monthFuture;

  final elevMap = {for (final e in elevators) e.id: e};

  final result = technicians.map((ProfileModel profile) {
    final myToday = todaySchedules
        .where((s) => s.technicianId == profile.id)
        .toList();

    final todayTasks = myToday.map((s) {
      final elev = elevMap[s.elevatorId];
      return TechnicianTask(
        buildingName: elev?.buildingName ?? 'Asansör',
        address: elev?.address,
        scheduledTime: s.scheduledDate,
        status: s.status,
        priority: s.priority,
        elevatorId: s.elevatorId,
        notes: s.notes,
      );
    }).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    return TechnicianStats(
      profile: profile,
      todayTasks: todayTasks,
      todayCompleted:
          myToday.where((s) => s.status == 'completed').length,
      monthlyCompleted: monthlyCount[profile.id] ?? 0,
    );
  }).toList();

  // Sort: active technicians first, then alphabetically by name.
  result.sort((a, b) {
    final aScore = a.hasActiveTasks ? 0 : 1;
    final bScore = b.hasActiveTasks ? 0 : 1;
    if (aScore != bScore) return aScore - bScore;
    return a.profile.displayName.compareTo(b.profile.displayName);
  });

  return result;
});

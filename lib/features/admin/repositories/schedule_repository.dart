import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/app_enums.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/providers/connectivity_providers.dart';

import '../models/schedule_model.dart';
import '../models/schedule_with_details.dart';

abstract interface class IScheduleRepository {
  Future<ScheduleModel> assignTask({required String elevatorId, required String technicianId, required DateTime scheduledDate, String? notes, required String createdBy, String priority = 'normal'});
  Future<int> bulkInsertPeriodicSchedules(List<Map<String, dynamic>> rows);
  Future<Set<String>> getScheduledElevatorIdsForMonth(DateTime month);
  Future<List<ScheduleModel>> getTechnicianTasks(String technicianId);
  Future<List<ScheduleModel>> getTechnicianPendingTasks(String technicianId);
  Future<List<ScheduleModel>> getAllSchedules({int? lookbackDays = 90});
  Future<List<ScheduleModel>> getSchedulesForDate(DateTime date);
  Stream<List<ScheduleModel>> getMyTasksStream(String technicianId);
  Future<List<ScheduleModel>> getTodayAllSchedules();
  Future<Map<String, int>> getMonthlyCompletedCountPerTechnician();
  Future<ScheduleModel> updateTaskStatus({required String taskId, required ScheduleStatus status});
  Future<void> completeMatchingSchedule({required String elevatorId, required String technicianId});
  Future<List<ScheduleWithDetails>> getAllSchedulesWithDetails({int? lookbackDays = 90});
  Future<List<ScheduleModel>> getSchedulesForDateRange(DateTime start, DateTime end, {int? limit});
  Future<DateTime?> getNextScheduledMaintenanceDate(String elevatorId);
}

/// Handles all CRUD operations against the `maintenance_schedules` table.
class ScheduleRepository implements IScheduleRepository {
  ScheduleRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'maintenance_schedules';

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Creates a new maintenance task assigned by a manager.
  ///
  /// [createdBy] should be the currently logged-in admin/manager's user ID.
  @override
  Future<ScheduleModel> assignTask({
    required String elevatorId,
    required String technicianId,
    required DateTime scheduledDate,
    String? notes,
    required String createdBy,
    String priority = 'normal',
  }) async {
    try {
      final response = await _client
          .from(_table)
          .insert({
            'elevator_id': elevatorId,
            'technician_id': technicianId,
            'scheduled_date': scheduledDate.toUtc().toIso8601String(),
            'status': 'pending',
            'priority': priority,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
            'created_by': createdBy,
          })
          .select()
          .single();

      final schedule = ScheduleModel.fromJson(response);

      // Push notification is handled server-side by the `notify-technician`
      // Supabase Edge Function, triggered automatically by the
      // `notify_on_schedule_insert` database trigger on `maintenance_schedules`.
      // No client-side notification dispatch needed here.

      return schedule;
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'assignTask');
    } catch (e) {
      throw mapUnknownException(e, 'assignTask');
    }
  }

  /// Bulk-inserts a list of auto-generated periodic maintenance tasks.
  ///
  /// Each row in [rows] must contain at minimum:
  ///   `elevator_id`, `scheduled_date`, `status`, `task_type`.
  /// `technician_id` is omitted — these tasks are unassigned and visible in
  /// the admin's "unassigned pool".
  ///
  /// Returns the number of rows actually inserted.
  @override
  Future<int> bulkInsertPeriodicSchedules(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return 0;
    try {
      final response = await _client.from(_table).insert(rows).select('id');
      return (response as List).length;
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'bulkInsertPeriodicSchedules');
    } catch (e) {
      throw mapUnknownException(e, 'bulkInsertPeriodicSchedules');
    }
  }

  /// Returns the set of elevator IDs that already have a periodic maintenance
  /// task scheduled within the calendar month defined by [month].
  @override
  Future<Set<String>> getScheduledElevatorIdsForMonth(DateTime month) async {
    final start = DateTime.utc(month.year, month.month, 1);
    final end = month.month < 12
        ? DateTime.utc(month.year, month.month + 1, 1)
        : DateTime.utc(month.year + 1, 1, 1);

    try {
      final response = await _client
          .from(_table)
          .select('elevator_id')
          .eq('task_type', 'periodic_maintenance')
          .gte('scheduled_date', start.toIso8601String())
          .lt('scheduled_date', end.toIso8601String());

      return (response as List)
          .map((r) => (r as Map<String, dynamic>)['elevator_id'] as String)
          .toSet();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getScheduledElevatorIdsForMonth');
    } catch (e) {
      throw mapUnknownException(e, 'getScheduledElevatorIdsForMonth');
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns all schedules assigned to [technicianId], ordered by date.
  @override
  Future<List<ScheduleModel>> getTechnicianTasks(String technicianId) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('technician_id', technicianId)
          .order('scheduled_date');

      return (response as List)
          .map((json) => ScheduleModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getTechnicianTasks');
    } catch (e) {
      throw mapUnknownException(e, 'getTechnicianTasks');
    }
  }

  /// Returns only **pending** schedules for [technicianId], ordered by date.
  /// Used on the technician's home dashboard.
  @override
  Future<List<ScheduleModel>> getTechnicianPendingTasks(
    String technicianId,
  ) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('technician_id', technicianId)
          .eq('status', 'pending')
          .order('scheduled_date');

      return (response as List)
          .map((json) => ScheduleModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getTechnicianPendingTasks');
    } catch (e) {
      throw mapUnknownException(e, 'getTechnicianPendingTasks');
    }
  }

  /// Returns all schedules across all technicians (admin view) within the last
  /// [lookbackDays] days. Pass null to fetch all history without limit.
  @override
  Future<List<ScheduleModel>> getAllSchedules({int? lookbackDays = 90}) async {
    try {
      var query = _client.from(_table).select();

      if (lookbackDays != null) {
        final since = DateTime.now().toUtc().subtract(Duration(days: lookbackDays));
        query = query.gte('scheduled_date', since.toIso8601String());
      }

      final response = await query.order('scheduled_date', ascending: false);

      return (response as List)
          .map((json) => ScheduleModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getAllSchedules');
    } catch (e) {
      throw mapUnknownException(e, 'getAllSchedules');
    }
  }

  /// Returns all schedules whose [scheduledDate] falls on [date] (local day).
  ///
  /// Used by the Admin Calendar to populate a selected day's task list.
  @override
  Future<List<ScheduleModel>> getSchedulesForDate(DateTime date) async {
    final local = date.toLocal();
    final start = DateTime(local.year, local.month, local.day).toUtc();
    final end = start.add(const Duration(days: 1));

    try {
      final response = await _client
          .from(_table)
          .select()
          .gte('scheduled_date', start.toIso8601String())
          .lt('scheduled_date', end.toIso8601String())
          .order('scheduled_date');

      return (response as List)
          .map((json) => ScheduleModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getSchedulesForDate');
    } catch (e) {
      throw mapUnknownException(e, 'getSchedulesForDate');
    }
  }

  /// Returns a **real-time stream** of all schedules for [technicianId],
  /// ordered by scheduled date ascending.
  ///
  /// Powered by Supabase Realtime — the stream re-emits whenever the
  /// `maintenance_schedules` table changes for this technician.
  @override
  Stream<List<ScheduleModel>> getMyTasksStream(String technicianId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('technician_id', technicianId)
        .order('scheduled_date')
        .map(
          (data) => data
              .map((json) => ScheduleModel.fromJson(json))
              .where((s) => s.status != ScheduleStatus.cancelled)
              .toList(),
        );
  }

  /// Returns all schedules for **today** across every technician, ordered by
  /// scheduled_date ascending.
  ///
  /// Used by the Technician Management view to compute per-technician workloads.
  @override
  Future<List<ScheduleModel>> getTodayAllSchedules() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final end = start.add(const Duration(days: 1));

    try {
      final response = await _client
          .from(_table)
          .select()
          .gte('scheduled_date', start.toIso8601String())
          .lt('scheduled_date', end.toIso8601String())
          .order('scheduled_date');

      return (response as List)
          .map((json) => ScheduleModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getTodayAllSchedules');
    } catch (e) {
      throw mapUnknownException(e, 'getTodayAllSchedules');
    }
  }

  /// Returns a map of `technicianId → completed task count` for the current
  /// calendar month.  Only the `technician_id` column is fetched to minimise
  /// payload size.
  @override
  Future<Map<String, int>> getMonthlyCompletedCountPerTechnician() async {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, 1);
    final end = now.month < 12
        ? DateTime.utc(now.year, now.month + 1, 1)
        : DateTime.utc(now.year + 1, 1, 1);

    try {
      final response = await _client
          .from(_table)
          .select('technician_id')
          .eq('status', 'completed')
          .gte('scheduled_date', start.toIso8601String())
          .lt('scheduled_date', end.toIso8601String());

      final counts = <String, int>{};
      for (final row in response as List) {
        final id =
            (row as Map<String, dynamic>)['technician_id'] as String? ?? '';
        if (id.isNotEmpty) counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getMonthlyCompletedCountPerTechnician');
    } catch (e) {
      throw mapUnknownException(e, 'getMonthlyCompletedCountPerTechnician');
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Updates the [status] of the schedule with [taskId].
  ///
  /// Valid statuses: 'pending', 'in_progress', 'completed', 'cancelled'.
  @override
  Future<ScheduleModel> updateTaskStatus({
    required String taskId,
    required ScheduleStatus status,
  }) async {
    try {
      final response = await _client
          .from(_table)
          .update({'status': status.dbValue})
          .eq('id', taskId)
          .select()
          .single();

      return ScheduleModel.fromJson(response);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'updateTaskStatus');
    } catch (e) {
      throw mapUnknownException(e, 'updateTaskStatus');
    }
  }

  /// Marks the first matching pending/in-progress schedule for an
  /// [elevatorId]+[technicianId] pair as **completed**.
  ///
  /// Called automatically after a technician submits a maintenance log.
  /// Errors are swallowed — this is a best-effort operation that must not
  /// block the primary log submission flow.
  @override
  Future<void> completeMatchingSchedule({
    required String elevatorId,
    required String technicianId,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final rows = await _client
          .from(_table)
          .select('id')
          .eq('elevator_id', elevatorId)
          .eq('technician_id', technicianId)
          .inFilter('status', ['pending', 'in_progress'])
          .gte('scheduled_date', startOfDay.toIso8601String())
          .lt('scheduled_date', endOfDay.toIso8601String())
          .limit(1);

      final items = rows as List;
      if (items.isEmpty) return;

      final scheduleId = items.first['id'] as String;
      await _client
          .from(_table)
          .update({'status': 'completed'})
          .eq('id', scheduleId);
    } catch (_) {
      // Best-effort — intentionally silent.
    }
  }

  /// Returns schedules with joined elevator and technician data.
  /// Returns schedules with joined elevator and technician data within the last
  /// [lookbackDays] days. Pass null to fetch all history without limit.
  @override
  Future<List<ScheduleWithDetails>> getAllSchedulesWithDetails({int? lookbackDays = 90}) async {
    try {
      var query = _client
          .from(_table)
          .select('*, elevators:elevator_id(building_name, address), profiles:technician_id(full_name)');

      if (lookbackDays != null) {
        final since = DateTime.now().toUtc().subtract(Duration(days: lookbackDays));
        query = query.gte('scheduled_date', since.toIso8601String());
      }

      final response = await query.order('scheduled_date', ascending: false);
          
      return (response as List).map((json) {
        final Map<String, dynamic> data = json as Map<String, dynamic>;
        final schedule = ScheduleModel.fromJson(data);
        
        final elevator = data['elevators'] as Map<String, dynamic>?;
        final profile = data['profiles'] as Map<String, dynamic>?;
        
        final techName = schedule.isUnassigned 
            ? 'Atanmamış' 
            : (profile?['full_name'] as String? ?? 'Teknisyen');
            
        return ScheduleWithDetails(
          schedule: schedule,
          buildingName: elevator?['building_name'] as String? ?? 'Asansör',
          address: elevator?['address'] as String?,
          technicianName: techName,
          technicianId: schedule.technicianId,
        );
      }).toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getAllSchedulesWithDetails');
    } catch (e) {
      throw mapUnknownException(e, 'getAllSchedulesWithDetails');
    }
  }

  /// Returns all schedules within the specified [start] and [end] date range,
  /// with an optional [limit].
  @override
  Future<List<ScheduleModel>> getSchedulesForDateRange(
    DateTime start,
    DateTime end, {
    int? limit,
  }) async {
    try {
      var query = _client
          .from(_table)
          .select()
          .gte('scheduled_date', start.toUtc().toIso8601String())
          .lte('scheduled_date', end.toUtc().toIso8601String())
          .order('scheduled_date', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      return (response as List)
          .map((json) => ScheduleModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getSchedulesForDateRange');
    } catch (e) {
      throw mapUnknownException(e, 'getSchedulesForDateRange');
    }
  }

  /// Returns the [DateTime] of the closest upcoming (pending) scheduled
  /// maintenance for this elevator, or `null` when none is scheduled.
  @override
  Future<DateTime?> getNextScheduledMaintenanceDate(String elevatorId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final response = await _client
          .from(_table)
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
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getNextScheduledMaintenanceDate($elevatorId)');
    } catch (e) {
      throw mapUnknownException(e, 'getNextScheduledMaintenanceDate($elevatorId)');
    }
  }
}

final scheduleRepositoryProvider = Provider<IScheduleRepository>((ref) {
  return ScheduleRepository(ref.watch(supabaseClientProvider));
});

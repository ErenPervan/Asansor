import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/schedule_model.dart';

/// Handles all CRUD operations against the `maintenance_schedules` table.
class ScheduleRepository {
  ScheduleRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'maintenance_schedules';

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Creates a new maintenance task assigned by a manager.
  ///
  /// [createdBy] should be the currently logged-in admin/manager's user ID.
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
    } on PostgrestException catch (e) {
      throw Exception('Görev atanamadı: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
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
  Future<int> bulkInsertPeriodicSchedules(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return 0;
    try {
      final response =
          await _client.from(_table).insert(rows).select('id');
      return (response as List).length;
    } on PostgrestException catch (e) {
      throw Exception('Toplu ekleme başarısız: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  /// Returns the set of elevator IDs that already have a periodic maintenance
  /// task scheduled within the calendar month defined by [month].
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
    } on PostgrestException catch (e) {
      throw Exception('Mevcut periyodik görevler sorgulanamadı: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns all schedules assigned to [technicianId], ordered by date.
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
    } on PostgrestException catch (e) {
      throw Exception('Görevler yüklenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  /// Returns only **pending** schedules for [technicianId], ordered by date.
  /// Used on the technician's home dashboard.
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
    } on PostgrestException catch (e) {
      throw Exception('Bekleyen görevler yüklenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  /// Returns all schedules across all technicians (admin view).
  Future<List<ScheduleModel>> getAllSchedules() async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .order('scheduled_date', ascending: false);

      return (response as List)
          .map((json) => ScheduleModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Tüm görevler yüklenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  /// Returns all schedules whose [scheduledDate] falls on [date] (local day).
  ///
  /// Used by the Admin Calendar to populate a selected day's task list.
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
    } on PostgrestException catch (e) {
      throw Exception('Günlük görevler yüklenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  /// Returns a **real-time stream** of all schedules for [technicianId],
  /// ordered by scheduled date ascending.
  ///
  /// Powered by Supabase Realtime — the stream re-emits whenever the
  /// `maintenance_schedules` table changes for this technician.
  Stream<List<ScheduleModel>> getMyTasksStream(String technicianId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('technician_id', technicianId)
        .order('scheduled_date')
        .map(
          (data) => data
              .map((json) => ScheduleModel.fromJson(json))
              .where((s) => s.status != 'cancelled')
              .toList(),
        );
  }

  /// Returns all schedules for **today** across every technician, ordered by
  /// scheduled_date ascending.
  ///
  /// Used by the Technician Management view to compute per-technician workloads.
  Future<List<ScheduleModel>> getTodayAllSchedules() async {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).toUtc();
    final end = start.add(const Duration(days: 1));

    try {
      final response = await _client
          .from(_table)
          .select()
          .gte('scheduled_date', start.toIso8601String())
          .lt('scheduled_date', end.toIso8601String())
          .order('scheduled_date');

      return (response as List)
          .map((json) =>
              ScheduleModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Bugünkü görevler yüklenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  /// Returns a map of `technicianId → completed task count` for the current
  /// calendar month.  Only the `technician_id` column is fetched to minimise
  /// payload size.
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
            (row as Map<String, dynamic>)['technician_id'] as String? ??
                '';
        if (id.isNotEmpty) counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } on PostgrestException catch (e) {
      throw Exception('Aylık tamamlananlar yüklenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Updates the [status] of the schedule with [taskId].
  ///
  /// Valid statuses: 'pending', 'in_progress', 'completed', 'cancelled'.
  Future<ScheduleModel> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    try {
      final response = await _client
          .from(_table)
          .update({'status': status})
          .eq('id', taskId)
          .select()
          .single();

      return ScheduleModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Durum güncellenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  /// Marks the first matching pending/in-progress schedule for an
  /// [elevatorId]+[technicianId] pair as **completed**.
  ///
  /// Called automatically after a technician submits a maintenance log.
  /// Errors are swallowed — this is a best-effort operation that must not
  /// block the primary log submission flow.
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
}

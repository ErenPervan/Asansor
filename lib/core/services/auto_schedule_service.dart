import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/elevator/repositories/elevator_repository.dart';
import '../../features/admin/repositories/schedule_repository.dart';

/// Result returned by [AutoScheduleService.generateMonthlyMaintenances].
class AutoScheduleResult {
  const AutoScheduleResult({required this.inserted, required this.skipped});

  /// Number of new periodic maintenance tasks created.
  final int inserted;

  /// Number of elevators skipped because they were already scheduled or
  /// had no [maintenanceDay] set.
  final int skipped;

  @override
  String toString() =>
      'AutoScheduleResult(inserted: $inserted, skipped: $skipped)';
}

/// Service that auto-generates unassigned periodic maintenance tasks for a
/// given calendar month.
///
/// ### Algorithm
/// 1. Fetch all elevators that have a `maintenance_day` configured.
/// 2. Query `maintenance_schedules` to find which of those elevators already
///    have a `periodic_maintenance` task for [targetMonth].
/// 3. For each elevator that does NOT yet have one, build a row where:
///    - `scheduled_date` = year/month from [targetMonth] + day from elevator
///    - `task_type`      = 'periodic_maintenance'
///    - `status`         = 'pending'
///    - `technician_id`  = null (admin assigns later)
/// 4. Bulk-insert the new rows.
///
/// ### Usage
/// ```dart
/// final service = AutoScheduleService(client);
/// final result  = await service.generateMonthlyMaintenances(DateTime.now());
/// print('${result.inserted} tasks created, ${result.skipped} already existed');
/// ```
class AutoScheduleService {
  AutoScheduleService(
    SupabaseClient client, {
    @visibleForTesting ElevatorRepository? elevatorRepo,
    @visibleForTesting ScheduleRepository? scheduleRepo,
  }) : _elevatorRepo = elevatorRepo ?? ElevatorRepository(client),
       _scheduleRepo = scheduleRepo ?? ScheduleRepository(client);

  final ElevatorRepository _elevatorRepo;
  final ScheduleRepository _scheduleRepo;

  /// Generates periodic maintenance tasks for the calendar month of [targetMonth].
  ///
  /// Only elevators with a `maintenance_day` value are considered.
  /// Elevators that already have a `periodic_maintenance` task for the month
  /// are silently skipped to prevent duplicates.
  ///
  /// Returns an [AutoScheduleResult] with counts of inserted and skipped tasks.
  Future<AutoScheduleResult> generateMonthlyMaintenances(
    DateTime targetMonth,
  ) async {
    // ── 1. Load all elevators that have a maintenance contract ────────────────
    final allElevators = await _elevatorRepo.getAllElevators();
    final contractElevators = allElevators
        .where((e) => e.maintenanceDay != null)
        .toList();

    if (contractElevators.isEmpty) {
      return const AutoScheduleResult(inserted: 0, skipped: 0);
    }

    // ── 2. Find elevators already scheduled for this month ────────────────────
    final alreadyScheduled = await _scheduleRepo
        .getScheduledElevatorIdsForMonth(targetMonth);

    // ── 3. Filter to only unscheduled elevators ───────────────────────────────
    final toSchedule = contractElevators
        .where((e) => !alreadyScheduled.contains(e.id))
        .toList();

    final skippedCount = contractElevators.length - toSchedule.length;

    if (toSchedule.isEmpty) {
      return AutoScheduleResult(inserted: 0, skipped: skippedCount);
    }

    // ── 4. Build insert rows ──────────────────────────────────────────────────
    //
    // scheduled_date is always midnight UTC on the contract day of targetMonth.
    // maintenance_day is capped at 28 by the DB check constraint, so this date
    // is valid for every calendar month including February.
    final rows = toSchedule.map((elevator) {
      final scheduledDate = DateTime.utc(
        targetMonth.year,
        targetMonth.month,
        elevator.maintenanceDay!,
      );

      return <String, dynamic>{
        'elevator_id': elevator.id,
        'scheduled_date': scheduledDate.toIso8601String(),
        'status': 'pending',
        'priority': 'normal',
        'task_type': 'periodic_maintenance',
        // technician_id is intentionally omitted — null in the DB means
        // "unassigned"; the admin will assign from the pool later.
      };
    }).toList();

    // ── 5. Bulk insert ────────────────────────────────────────────────────────
    final inserted = await _scheduleRepo.bulkInsertPeriodicSchedules(rows);

    return AutoScheduleResult(inserted: inserted, skipped: skippedCount);
  }
}

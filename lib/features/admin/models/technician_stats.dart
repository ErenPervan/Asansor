import 'profile_model.dart';

/// A single scheduled task enriched with elevator display info.
/// Used in the Technician Management view's detail bottom sheet.
class TechnicianTask {
  const TechnicianTask({
    required this.buildingName,
    this.address,
    required this.scheduledTime,
    required this.status,
    required this.priority,
    required this.elevatorId,
    this.notes,
  });

  final String buildingName;
  final String? address;
  final DateTime scheduledTime;

  /// One of: 'pending' | 'in_progress' | 'completed' | 'cancelled'
  final String status;

  /// One of: 'low' | 'normal' | 'high' | 'emergency'
  final String priority;

  final String elevatorId;
  final String? notes;

  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'pending' || status == 'in_progress';
}

/// Aggregated stats for a single technician for the current day and month.
class TechnicianStats {
  const TechnicianStats({
    required this.profile,
    required this.todayTasks,
    required this.todayCompleted,
    required this.monthlyCompleted,
  });

  final ProfileModel profile;

  /// Today's tasks sorted ascending by [scheduledTime].
  final List<TechnicianTask> todayTasks;

  /// Number of tasks with status 'completed' today.
  final int todayCompleted;

  /// Number of tasks with status 'completed' in the current calendar month.
  final int monthlyCompleted;

  // ── Computed ────────────────────────────────────────────────────────────

  int get todayTotal => todayTasks.length;
  int get todayPending => todayTotal - todayCompleted;

  /// `true` when the technician has at least one pending or in-progress task.
  bool get hasActiveTasks => todayTasks.any((t) => t.isActive);

  /// 0.0–1.0 fraction for the workload progress bar.
  double get progressValue =>
      todayTotal == 0 ? 0.0 : (todayCompleted / todayTotal).clamp(0.0, 1.0);
}

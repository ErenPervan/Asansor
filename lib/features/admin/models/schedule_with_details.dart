import 'schedule_model.dart';

/// [ScheduleModel] enriched with human-readable elevator and technician
/// display names, produced by [allSchedulesWithDetailsProvider].
class ScheduleWithDetails {
  const ScheduleWithDetails({
    required this.schedule,
    required this.buildingName,
    this.address,
    required this.technicianName,
    required this.technicianId,
  });

  final ScheduleModel schedule;
  final String buildingName;
  final String? address;
  final String technicianName;
  final String technicianId;

  // ── Convenience proxies ───────────────────────────────────────────────────

  String get id => schedule.id;
  String get elevatorId => schedule.elevatorId;
  DateTime get scheduledDate => schedule.scheduledDate;
  String get status => schedule.status;
  String get priority => schedule.priority;
  String? get notes => schedule.notes;

  bool get isCompleted => schedule.status == 'completed';
  bool get isCancelled => schedule.status == 'cancelled';
  bool get isPeriodicMaintenance => schedule.isPeriodicMaintenance;
  bool get isUnassigned => schedule.isUnassigned;

  @override
  String toString() =>
      'ScheduleWithDetails(id: $id, building: $buildingName, '
      'technician: $technicianName, status: $status, priority: $priority)';
}

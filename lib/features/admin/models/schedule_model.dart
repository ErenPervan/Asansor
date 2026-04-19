/// Data model for the `maintenance_schedules` table.
///
/// A [ScheduleModel] represents a task assigned by a manager/admin to a
/// specific technician for a given elevator on a scheduled date.
///
/// [technicianId] is an empty string when the task is auto-generated and
/// not yet assigned to anyone (task_type == 'periodic_maintenance').
///
/// Expected table schema (see supabase/migrations/ for the full DDL):
/// ```
///   id              uuid
///   elevator_id     uuid NOT NULL
///   technician_id   uuid  (nullable — unassigned periodic tasks have no technician)
///   scheduled_date  timestamptz NOT NULL
///   status          text NOT NULL default 'pending'
///   priority        text NOT NULL default 'normal'
///   task_type       text NOT NULL default 'manual'
///   notes           text
///   created_by      uuid
///   created_at      timestamptz
/// ```
class ScheduleModel {
  const ScheduleModel({
    required this.id,
    required this.elevatorId,
    required this.technicianId,
    required this.scheduledDate,
    required this.status,
    this.priority = 'normal',
    this.taskType = 'manual',
    this.notes,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String elevatorId;

  /// Empty string means the task is unassigned (auto-generated periodic task).
  final String technicianId;

  /// ISO-8601 timestamp for when the maintenance is scheduled.
  final DateTime scheduledDate;

  /// One of: 'pending' | 'in_progress' | 'completed' | 'cancelled'
  final String status;

  /// One of: 'low' | 'normal' | 'high' | 'emergency'
  final String priority;

  /// One of: 'manual' | 'periodic_maintenance'
  final String taskType;

  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

  bool get isPeriodicMaintenance => taskType == 'periodic_maintenance';
  bool get isUnassigned => technicianId.isEmpty;

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] as String,
      elevatorId: (json['elevator_id'] as String?) ?? '',
      technicianId: (json['technician_id'] as String?) ?? '',
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      status: (json['status'] as String?) ?? 'pending',
      priority: (json['priority'] as String?) ?? 'normal',
      taskType: (json['task_type'] as String?) ?? 'manual',
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'elevator_id': elevatorId,
        if (technicianId.isNotEmpty) 'technician_id': technicianId,
        'scheduled_date': scheduledDate.toIso8601String(),
        'status': status,
        'priority': priority,
        'task_type': taskType,
        'notes': notes,
        'created_by': createdBy,
      };

  ScheduleModel copyWith({
    String? id,
    String? elevatorId,
    String? technicianId,
    DateTime? scheduledDate,
    String? status,
    String? priority,
    String? taskType,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      elevatorId: elevatorId ?? this.elevatorId,
      technicianId: technicianId ?? this.technicianId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      taskType: taskType ?? this.taskType,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'ScheduleModel(id: $id, elevatorId: $elevatorId, '
      'technicianId: $technicianId, status: $status, priority: $priority, '
      'taskType: $taskType, scheduledDate: $scheduledDate)';
}

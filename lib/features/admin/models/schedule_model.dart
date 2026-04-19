/// Data model for the `maintenance_schedules` table.
///
/// A [ScheduleModel] represents a task assigned by a manager/admin to a
/// specific technician for a given elevator on a scheduled date.
///
/// Expected table schema:
/// ```sql
/// create table maintenance_schedules (
///   id              uuid primary key default gen_random_uuid(),
///   elevator_id     uuid not null references elevators(id),
///   technician_id   uuid not null references auth.users(id),
///   scheduled_date  timestamptz not null,
///   status          text not null default 'pending',
///   priority        text not null default 'normal',
///   notes           text,
///   created_by      uuid references auth.users(id),
///   created_at      timestamptz default now()
/// );
///
/// -- Migration (run once if the table already exists):
/// alter table maintenance_schedules
///   add column if not exists priority text not null default 'normal';
///
/// -- Enable real-time replication for the technician's live agenda:
/// alter publication supabase_realtime add table maintenance_schedules;
/// ```
class ScheduleModel {
  const ScheduleModel({
    required this.id,
    required this.elevatorId,
    required this.technicianId,
    required this.scheduledDate,
    required this.status,
    this.priority = 'normal',
    this.notes,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String elevatorId;
  final String technicianId;

  /// ISO-8601 timestamp for when the maintenance is scheduled.
  final DateTime scheduledDate;

  /// One of: 'pending' | 'in_progress' | 'completed' | 'cancelled'
  final String status;

  /// One of: 'low' | 'normal' | 'high' | 'emergency'
  final String priority;

  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

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
        'technician_id': technicianId,
        'scheduled_date': scheduledDate.toIso8601String(),
        'status': status,
        'priority': priority,
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
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'ScheduleModel(id: $id, elevatorId: $elevatorId, '
      'technicianId: $technicianId, status: $status, priority: $priority, '
      'scheduledDate: $scheduledDate)';
}

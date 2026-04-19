/// Maps to the `maintenance_logs` table in Supabase.
class MaintenanceLogModel {
  const MaintenanceLogModel({
    required this.id,
    required this.elevatorId,
    required this.technicianId,
    this.notes,
    required this.isApproved,
    required this.maintenanceDate,
    this.isOfflineQueued = false,
  });

  final String id;
  final String elevatorId;

  /// References the authenticated user's UUID (auth.users).
  final String technicianId;

  /// Nullable: the notes column may not have a NOT NULL constraint in the DB.
  final String? notes;

  final bool isApproved;
  final DateTime maintenanceDate;

  /// `true` when this record was created offline and is waiting in the
  /// local sync queue. It has no corresponding row in Supabase yet.
  final bool isOfflineQueued;

  factory MaintenanceLogModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceLogModel(
      id: json['id'] as String,
      // FK columns: null-safe cast + empty-string fallback.
      elevatorId: (json['elevator_id'] as String?) ?? '',
      technicianId: (json['technician_id'] as String?) ?? '',
      // Nullable by design — no fallback applied.
      notes: json['notes'] as String?,
      // Boolean columns: guard against null with a sensible default.
      isApproved: (json['is_approved'] as bool?) ?? false,
      // DateTime: parse only if non-null; use epoch as a safe sentinel.
      maintenanceDate: json['maintenance_date'] != null
          ? DateTime.parse(json['maintenance_date'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'elevator_id': elevatorId,
      'technician_id': technicianId,
      'notes': notes,
      'is_approved': isApproved,
      'maintenance_date': maintenanceDate.toIso8601String(),
    };
  }

  MaintenanceLogModel copyWith({
    String? id,
    String? elevatorId,
    String? technicianId,
    String? notes,
    bool? isApproved,
    DateTime? maintenanceDate,
    bool? isOfflineQueued,
  }) {
    return MaintenanceLogModel(
      id: id ?? this.id,
      elevatorId: elevatorId ?? this.elevatorId,
      technicianId: technicianId ?? this.technicianId,
      notes: notes ?? this.notes,
      isApproved: isApproved ?? this.isApproved,
      maintenanceDate: maintenanceDate ?? this.maintenanceDate,
      isOfflineQueued: isOfflineQueued ?? this.isOfflineQueued,
    );
  }

  @override
  String toString() =>
      'MaintenanceLogModel(id: $id, elevatorId: $elevatorId, '
      'technicianId: $technicianId, isApproved: $isApproved)';
}

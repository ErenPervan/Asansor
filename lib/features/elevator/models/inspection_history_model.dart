class InspectionHistoryModel {
  const InspectionHistoryModel({
    required this.id,
    required this.elevatorId,
    required this.technicianId,
    required this.inspectionDate,
    required this.status,
    this.inspectorName,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String elevatorId;
  final String technicianId;
  final DateTime inspectionDate;
  final String status; // 'red', 'yellow', 'blue', 'green', 'none'
  final String? inspectorName;
  final String? notes;
  final DateTime? createdAt;

  factory InspectionHistoryModel.fromJson(Map<String, dynamic> json) {
    return InspectionHistoryModel(
      id: json['id'] as String,
      elevatorId: json['elevator_id'] as String,
      technicianId: json['technician_id'] as String,
      inspectionDate: DateTime.parse(json['inspection_date'] as String).toLocal(),
      status: json['status'] as String,
      inspectorName: json['inspector_name'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'elevator_id': elevatorId,
      'technician_id': technicianId,
      'inspection_date': inspectionDate.toUtc().toIso8601String(),
      'status': status,
      if (inspectorName != null) 'inspector_name': inspectorName,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }

  InspectionHistoryModel copyWith({
    String? id,
    String? elevatorId,
    String? technicianId,
    DateTime? inspectionDate,
    String? status,
    String? inspectorName,
    String? notes,
    DateTime? createdAt,
  }) {
    return InspectionHistoryModel(
      id: id ?? this.id,
      elevatorId: elevatorId ?? this.elevatorId,
      technicianId: technicianId ?? this.technicianId,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      status: status ?? this.status,
      inspectorName: inspectorName ?? this.inspectorName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

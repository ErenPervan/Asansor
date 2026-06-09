/// Maps to the `fault_reports` table in Supabase.
///
/// Optional DB migration (run once to unlock resolution tracking):
/// ```sql
/// alter table fault_reports
///   add column if not exists resolved_at      timestamptz,
///   add column if not exists resolution_notes text;
/// ```
class FaultReportModel {
  const FaultReportModel({
    required this.id,
    required this.elevatorId,
    required this.description,
    this.photoUrl,
    this.faultType,
    this.priority,
    required this.isResolved,
    required this.reportedAt,
    this.resolvedAt,
    this.resolutionNotes,
    this.isOfflineQueued = false,
  });

  final String id;
  final String elevatorId;

  /// The fault description; falls back to an empty string if the DB column
  /// has no NOT NULL constraint and the row was inserted without a value.
  final String description;

  /// Optional URL pointing to a photo stored in Supabase Storage.
  final String? photoUrl;

  /// Arıza kategorisi (örn. 'Kapı Motoru', 'Anakart', vs.)
  final String? faultType;

  /// Öncelik seviyesi: 'low' | 'normal' | 'high' | 'emergency'
  final String? priority;

  final bool isResolved;
  final DateTime reportedAt;

  /// Populated only after [isResolved] is set to true (optional column).
  final DateTime? resolvedAt;

  /// Free-text notes added by the technician when marking the fault resolved.
  final String? resolutionNotes;

  /// `true` when this record was created offline and is waiting in the
  /// local sync queue. It has no corresponding row in Supabase yet.
  final bool isOfflineQueued;

  factory FaultReportModel.fromJson(Map<String, dynamic> json) {
    return FaultReportModel(
      id: json['id'] as String,
      elevatorId: (json['elevator_id'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      photoUrl: json['photo_url'] as String?,
      faultType: json['fault_type'] as String?,
      priority: json['priority'] as String?,
      isResolved: (json['is_resolved'] as bool?) ?? false,
      reportedAt: json['reported_at'] != null
          ? DateTime.parse(json['reported_at'] as String)
          : throw const FormatException('reported_at is required for FaultReportModel'),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolutionNotes: json['resolution_notes'] as String?,
    );
  }

  factory FaultReportModel.fromOfflineQueue(Map<String, dynamic> json) {
    return FaultReportModel.fromJson(json).copyWith(isOfflineQueued: true);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'elevator_id': elevatorId,
      'description': description,
      'photo_url': photoUrl,
      if (faultType != null) 'fault_type': faultType,
      if (priority != null) 'priority': priority,
      'is_resolved': isResolved,
      'reported_at': reportedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolution_notes': resolutionNotes,
    };
  }

  FaultReportModel copyWith({
    String? id,
    String? elevatorId,
    String? description,
    String? photoUrl,
    String? faultType,
    String? priority,
    bool? isResolved,
    DateTime? reportedAt,
    DateTime? resolvedAt,
    String? resolutionNotes,
    bool? isOfflineQueued,
  }) {
    return FaultReportModel(
      id: id ?? this.id,
      elevatorId: elevatorId ?? this.elevatorId,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      faultType: faultType ?? this.faultType,
      priority: priority ?? this.priority,
      isResolved: isResolved ?? this.isResolved,
      reportedAt: reportedAt ?? this.reportedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      isOfflineQueued: isOfflineQueued ?? this.isOfflineQueued,
    );
  }

  @override
  String toString() =>
      'FaultReportModel(id: $id, elevatorId: $elevatorId, '
      'isResolved: $isResolved, reportedAt: $reportedAt)';
}

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
    required this.isResolved,
    required this.reportedAt,
    this.resolvedAt,
    this.resolutionNotes,
    this.isOfflineQueued = false,
    this.faultType,
    this.priority,
  });

  final String id;
  final String elevatorId;

  /// The fault description; falls back to an empty string if the DB column
  /// has no NOT NULL constraint and the row was inserted without a value.
  final String description;

  /// Optional URL pointing to a photo stored in Supabase Storage.
  final String? photoUrl;

  final bool isResolved;
  final DateTime reportedAt;

  /// Populated only after [isResolved] is set to true (optional column).
  final DateTime? resolvedAt;

  /// Free-text notes added by the technician when marking the fault resolved.
  final String? resolutionNotes;

  /// `true` when this record was created offline and is waiting in the
  /// local sync queue. It has no corresponding row in Supabase yet.
  final bool isOfflineQueued;

  /// E.g. 'mechanic', 'electric', 'trapped'
  final String? faultType;

  /// E.g. 'emergency', 'high', 'normal'
  final String? priority;

  factory FaultReportModel.fromJson(Map<String, dynamic> json) {
    return FaultReportModel(
      id: json['id'] as String,
      elevatorId: (json['elevator_id'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      photoUrl: json['photo_url'] as String?,
      isResolved: (json['is_resolved'] as bool?) ?? false,
      reportedAt: json['reported_at'] != null
          ? DateTime.parse(json['reported_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolutionNotes: json['resolution_notes'] as String?,
      faultType: json['fault_type'] as String?,
      priority: json['priority'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'elevator_id': elevatorId,
      'description': description,
      'photo_url': photoUrl,
      'is_resolved': isResolved,
      'reported_at': reportedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolution_notes': resolutionNotes,
      'fault_type': faultType,
      'priority': priority,
    };
  }

  FaultReportModel copyWith({
    String? id,
    String? elevatorId,
    String? description,
    String? photoUrl,
    bool? isResolved,
    DateTime? reportedAt,
    DateTime? resolvedAt,
    String? resolutionNotes,
    bool? isOfflineQueued,
    String? faultType,
    String? priority,
  }) {
    return FaultReportModel(
      id: id ?? this.id,
      elevatorId: elevatorId ?? this.elevatorId,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      isResolved: isResolved ?? this.isResolved,
      reportedAt: reportedAt ?? this.reportedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      isOfflineQueued: isOfflineQueued ?? this.isOfflineQueued,
      faultType: faultType ?? this.faultType,
      priority: priority ?? this.priority,
    );
  }

  @override
  String toString() =>
      'FaultReportModel(id: $id, elevatorId: $elevatorId, '
      'isResolved: $isResolved, reportedAt: $reportedAt, '
      'faultType: $faultType, priority: $priority)';
}

/// Maps to the `maintenance_logs` table in Supabase.
class MaintenanceLogModel {
  const MaintenanceLogModel({
    required this.id,
    required this.elevatorId,
    required this.technicianId,
    this.notes,
    required this.isApproved,
    required this.maintenanceDate,
    this.checklist,
    this.photos,
    this.signatureUrl,
    this.technicianName,
    this.isOfflineQueued = false,
    this.pdfUrl,
    this.customerSignatureUrl,
  });

  final String id;
  final String elevatorId;

  /// References the authenticated user's UUID (auth.users).
  final String technicianId;

  /// The full name of the technician (resolved from profiles table).
  final String? technicianName;

  /// Nullable: the notes column may not have a NOT NULL constraint in the DB.
  final String? notes;

  final bool isApproved;
  final DateTime maintenanceDate;

  /// JSON representing checked items, e.g. {"cabin_light": true, "doors_checked": true}
  final Map<String, bool>? checklist;

  /// Array of uploaded photo URLs
  final List<String>? photos;

  /// URL of the uploaded technician signature image
  final String? signatureUrl;

  /// URL of the generated PDF maintenance report in Supabase Storage.
  final String? pdfUrl;

  /// URL of the building representative (customer) signature image.
  final String? customerSignatureUrl;

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
      checklist: json['checklist'] != null
          ? Map<String, bool>.from(json['checklist'] as Map)
          : null,
      photos: json['photos'] != null
          ? List<String>.from(json['photos'] as List)
          : null,
      signatureUrl: json['signature_url'] as String?,
      technicianName: (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      customerSignatureUrl: json['customer_signature_url'] as String?,
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
      'checklist': checklist,
      'photos': photos,
      'signature_url': signatureUrl,
      'pdf_url': pdfUrl,
      'customer_signature_url': customerSignatureUrl,
    };
  }

  MaintenanceLogModel copyWith({
    String? id,
    String? elevatorId,
    String? technicianId,
    String? notes,
    bool? isApproved,
    DateTime? maintenanceDate,
    Map<String, bool>? checklist,
    List<String>? photos,
    String? signatureUrl,
    bool? isOfflineQueued,
    String? pdfUrl,
    String? customerSignatureUrl,
  }) {
    return MaintenanceLogModel(
      id: id ?? this.id,
      elevatorId: elevatorId ?? this.elevatorId,
      technicianId: technicianId ?? this.technicianId,
      notes: notes ?? this.notes,
      isApproved: isApproved ?? this.isApproved,
      maintenanceDate: maintenanceDate ?? this.maintenanceDate,
      checklist: checklist ?? this.checklist,
      photos: photos ?? this.photos,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      isOfflineQueued: isOfflineQueued ?? this.isOfflineQueued,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      customerSignatureUrl: customerSignatureUrl ?? this.customerSignatureUrl,
    );
  }

  @override
  String toString() =>
      'MaintenanceLogModel(id: $id, elevatorId: $elevatorId, '
      'technicianId: $technicianId, isApproved: $isApproved)';
}

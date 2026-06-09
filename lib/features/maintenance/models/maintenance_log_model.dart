/// Maps to the `maintenance_logs` table in Supabase.
class MaintenanceLogModel {
  const MaintenanceLogModel({
    required this.id,
    required this.elevatorId,
    required this.technicianId,
    this.notes,
    required this.isApproved,
    required this.maintenanceDate,
    this.pdfUrl,
    this.technicianName,
    this.checklist,
    this.photos,
    this.signatureUrl,
    this.customerSignatureUrl,
    this.isOfflineQueued = false,
  });

  final String id;
  final String elevatorId;

  /// References the authenticated user's UUID (auth.users / profiles.id).
  final String technicianId;

  /// Nullable: the notes column may not have a NOT NULL constraint in the DB.
  final String? notes;

  final bool isApproved;
  final DateTime maintenanceDate;

  /// URL to the generated PDF report, if any.
  final String? pdfUrl;

  /// The technician's full name resolved via a JOIN on the `profiles` table.
  ///
  /// Populated only when the query uses:
  ///   `.select('*, profiles:technician_id(full_name)')`
  ///
  /// `null` when the log was created offline (no join possible) or when the
  /// profile row does not yet exist for the technician UUID.
  final String? technicianName;

  /// The checklist state saved as a JSON object.
  final Map<String, dynamic>? checklist;

  /// Photo URLs (or local paths while queued offline).
  final List<String>? photos;

  /// Technician's signature URL (or local path while queued offline).
  final String? signatureUrl;

  /// Customer's signature URL (or local path while queued offline).
  final String? customerSignatureUrl;

  /// `true` when this record was created offline and is waiting in the
  /// local sync queue. It has no corresponding row in Supabase yet.
  final bool isOfflineQueued;

  factory MaintenanceLogModel.fromJson(Map<String, dynamic> json) {
    // The profiles join returns a nested map: { 'full_name': '...' }
    // or null when the technician profile does not exist.
    final profilesData = json['profiles'] as Map<String, dynamic>?;

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
          : throw const FormatException('maintenance_date is required for MaintenanceLogModel'),
      pdfUrl: json['pdf_url'] as String?,
      technicianName: profilesData?['full_name'] as String?,
      checklist: json['checklist'] as Map<String, dynamic>?,
      photos: (json['photos'] as List?)?.whereType<String>().toList(),
      signatureUrl: json['signature_url'] as String?,
      customerSignatureUrl: json['customer_signature_url'] as String?,
    );
  }

  factory MaintenanceLogModel.fromOfflineQueue(Map<String, dynamic> json) {
    return MaintenanceLogModel.fromJson(json).copyWith(isOfflineQueued: true);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'elevator_id': elevatorId,
      'technician_id': technicianId,
      'notes': notes,
      'is_approved': isApproved,
      'maintenance_date': maintenanceDate.toIso8601String(),
      'pdf_url': pdfUrl,
      'checklist': checklist,
      if (photos != null) 'photos': photos,
      if (signatureUrl != null) 'signature_url': signatureUrl,
      if (customerSignatureUrl != null)
        'customer_signature_url': customerSignatureUrl,
      // technicianName is a read-only joined field; never written back to DB.
    };
  }

  MaintenanceLogModel copyWith({
    String? id,
    String? elevatorId,
    String? technicianId,
    String? notes,
    bool? isApproved,
    DateTime? maintenanceDate,
    String? pdfUrl,
    String? technicianName,
    Map<String, dynamic>? checklist,
    List<String>? photos,
    String? signatureUrl,
    String? customerSignatureUrl,
    bool? isOfflineQueued,
  }) {
    return MaintenanceLogModel(
      id: id ?? this.id,
      elevatorId: elevatorId ?? this.elevatorId,
      technicianId: technicianId ?? this.technicianId,
      notes: notes ?? this.notes,
      isApproved: isApproved ?? this.isApproved,
      maintenanceDate: maintenanceDate ?? this.maintenanceDate,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      technicianName: technicianName ?? this.technicianName,
      checklist: checklist ?? this.checklist,
      photos: photos ?? this.photos,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      customerSignatureUrl: customerSignatureUrl ?? this.customerSignatureUrl,
      isOfflineQueued: isOfflineQueued ?? this.isOfflineQueued,
    );
  }

  @override
  String toString() =>
      'MaintenanceLogModel(id: $id, elevatorId: $elevatorId, '
      'technicianId: $technicianId, isApproved: $isApproved)';
}

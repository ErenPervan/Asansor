/// Maps to the `elevators` table in Supabase.
///
/// To enable map markers, add the following columns to your Supabase table:
/// ```sql
/// alter table elevators add column latitude  double precision;
/// alter table elevators add column longitude double precision;
/// ```
class ElevatorModel {
  const ElevatorModel({
    required this.id,
    required this.buildingName,
    this.address,
    required this.status,
    this.latitude,
    this.longitude,
    this.maintenanceDay,
    this.model,
    this.capacity,
    this.lastInspectionDate,
    this.nextInspectionDate,
    this.inspectionStatus = 'none',
  });

  final String id;
  final String buildingName;

  /// Nullable: the address column may not have a NOT NULL constraint in the DB.
  final String? address;

  /// Possible values: 'active' | 'inactive' | 'under_maintenance' | 'faulty'
  final String status;

  /// Geographic coordinates for the Live Map feature.
  /// Null when the elevator has not yet been geo-tagged.
  final double? latitude;
  final double? longitude;

  /// Contract-mandated day of the month (1–28) for periodic maintenance.
  /// Null means no periodic contract has been configured yet.
  final int? maintenanceDay;

  /// Manufacturer and model of the elevator.
  final String? model;

  /// Passenger/weight capacity.
  final int? capacity;

  /// The date when the last A-Type legal inspection occurred.
  final DateTime? lastInspectionDate;

  /// The date when the next A-Type legal inspection is due.
  final DateTime? nextInspectionDate;

  /// The current legal certification tag ('red', 'yellow', 'blue', 'green', 'none').
  final String inspectionStatus;

  factory ElevatorModel.fromJson(Map<String, dynamic> json) {
    return ElevatorModel(
      id: json['id'] as String,
      buildingName: (json['building_name'] as String?) ?? '',
      address: json['address'] as String?,
      status: (json['status'] as String?) ?? 'unknown',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      maintenanceDay: json['maintenance_day'] as int?,
      model: json['model'] as String?,
      capacity: json['capacity'] as int?,
      lastInspectionDate: json['last_inspection_date'] != null
          ? DateTime.parse(json['last_inspection_date'] as String).toLocal()
          : null,
      nextInspectionDate: json['next_inspection_date'] != null
          ? DateTime.parse(json['next_inspection_date'] as String).toLocal()
          : null,
      inspectionStatus: (json['inspection_status'] as String?) ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'building_name': buildingName,
      'address': address,
      'status': status,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (maintenanceDay != null) 'maintenance_day': maintenanceDay,
      if (model != null) 'model': model,
      if (capacity != null) 'capacity': capacity,
      if (lastInspectionDate != null)
        'last_inspection_date': lastInspectionDate!.toUtc().toIso8601String(),
      if (nextInspectionDate != null)
        'next_inspection_date': nextInspectionDate!.toUtc().toIso8601String(),
      'inspection_status': inspectionStatus,
    };
  }

  ElevatorModel copyWith({
    String? id,
    String? buildingName,
    String? address,
    String? status,
    double? latitude,
    double? longitude,
    int? maintenanceDay,
    String? model,
    int? capacity,
    DateTime? lastInspectionDate,
    DateTime? nextInspectionDate,
    String? inspectionStatus,
  }) {
    return ElevatorModel(
      id: id ?? this.id,
      buildingName: buildingName ?? this.buildingName,
      address: address ?? this.address,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      maintenanceDay: maintenanceDay ?? this.maintenanceDay,
      model: model ?? this.model,
      capacity: capacity ?? this.capacity,
      lastInspectionDate: lastInspectionDate ?? this.lastInspectionDate,
      nextInspectionDate: nextInspectionDate ?? this.nextInspectionDate,
      inspectionStatus: inspectionStatus ?? this.inspectionStatus,
    );
  }

  /// Returns true only when this elevator has valid map coordinates.
  bool get hasMappableLocation => latitude != null && longitude != null;

  /// Returns true when a periodic maintenance contract day has been set.
  bool get hasMaintenanceContract => maintenanceDay != null;

  /// Calculates the days remaining until the next inspection.
  /// Returns null if [nextInspectionDate] is not set.
  int? get daysUntilNextInspection {
    if (nextInspectionDate == null) return null;
    final now = DateTime.now();
    final difference = nextInspectionDate!.difference(now);
    return difference.inDays;
  }

  /// Returns true if the next inspection is due in less than 30 days or is already overdue.
  bool get isInspectionUrgent {
    final days = daysUntilNextInspection;
    if (days == null) return false;
    return days < 30;
  }

  @override
  String toString() =>
      'ElevatorModel(id: $id, buildingName: $buildingName, '
      'status: $status, inspectionStatus: $inspectionStatus, '
      'nextInspection: $nextInspectionDate)';
}

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
    this.version = 1,
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

  /// Manufacturer and model name of the elevator unit (e.g. "Otis Gen2").
  /// Null when not yet recorded in the database.
  final String? model;

  /// Passenger/weight capacity of the elevator in kilograms (e.g. 630).
  /// Format for display in the UI as "${capacity} Kg".
  /// Null when not yet recorded in the database.
  final int? capacity;

  /// OCC Version number
  final int version;

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
      version: json['version'] as int? ?? 1,
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
      'version': version,
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
    int? version,
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
      version: version ?? this.version,
    );
  }

  /// Returns true only when this elevator has valid map coordinates.
  bool get hasMappableLocation => latitude != null && longitude != null;

  /// Returns true when a periodic maintenance contract day has been set.
  bool get hasMaintenanceContract => maintenanceDay != null;

  @override
  String toString() =>
      'ElevatorModel(id: $id, buildingName: $buildingName, '
      'address: $address, status: $status, '
      'model: $model, capacity: $capacity, '
      'lat: $latitude, lng: $longitude, version: $version)';
}

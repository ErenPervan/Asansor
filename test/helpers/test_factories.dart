import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';

/// Testlerde kullanılacak standart/örnek modeller üreten factory yardımcıları.
class TestFactories {
  static ElevatorModel createElevator({
    String id = 'elev-1',
    String buildingName = 'Test Building',
    String status = 'active',
    String? address = 'Test Address',
    String? model = 'Model X',
    int? capacity = 800,
    int? maintenanceDay = 15,
  }) {
    return ElevatorModel(
      id: id,
      buildingName: buildingName,
      status: status,
      address: address,
      model: model,
      capacity: capacity,
      maintenanceDay: maintenanceDay,
    );
  }

  static MaintenanceLogModel createMaintenanceLog({
    String id = 'log-1',
    String elevatorId = 'elev-1',
    String technicianId = 'tech-1',
    bool isApproved = true,
    String? notes = 'All good',
    DateTime? maintenanceDate,
    Map<String, dynamic> checklist = const {'doors': true},
  }) {
    return MaintenanceLogModel(
      id: id,
      elevatorId: elevatorId,
      technicianId: technicianId,
      maintenanceDate: maintenanceDate ?? DateTime(2026, 1, 15),
      isApproved: isApproved,
      notes: notes,
      checklist: checklist,
    );
  }
}

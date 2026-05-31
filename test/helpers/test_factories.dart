import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:asansor/features/admin/models/schedule_model.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/admin/models/technician_stats.dart';

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

  static FaultReportModel createFaultReport({
    String id = 'fault-1',
    String elevatorId = 'elev-1',
    String description = 'Test fault',
    String? photoUrl,
    String? faultType,
    String? priority,
    bool isResolved = false,
    DateTime? reportedAt,
    DateTime? resolvedAt,
    String? resolutionNotes,
    bool isOfflineQueued = false,
  }) {
    return FaultReportModel(
      id: id,
      elevatorId: elevatorId,
      description: description,
      photoUrl: photoUrl,
      faultType: faultType,
      priority: priority,
      isResolved: isResolved,
      reportedAt: reportedAt ?? DateTime(2026, 1, 15),
      resolvedAt: resolvedAt,
      resolutionNotes: resolutionNotes,
      isOfflineQueued: isOfflineQueued,
    );
  }

  static ScheduleModel createSchedule({
    String id = 'sched-1',
    String elevatorId = 'elev-1',
    String technicianId = 'tech-1',
    DateTime? scheduledDate,
    String status = 'pending',
    String priority = 'normal',
    String taskType = 'manual',
    String? notes,
  }) {
    return ScheduleModel(
      id: id,
      elevatorId: elevatorId,
      technicianId: technicianId,
      scheduledDate: scheduledDate ?? DateTime(2026, 1, 15),
      status: status,
      priority: priority,
      taskType: taskType,
      notes: notes,
    );
  }

  static ProfileModel createProfile({
    String id = 'prof-1',
    String? email = 'test@test.com',
    String? fullName = 'Test User',
    String? phone,
    String role = 'technician',
    String? elevatorId,
  }) {
    return ProfileModel(
      id: id,
      email: email,
      fullName: fullName,
      phone: phone,
      role: role,
      elevatorId: elevatorId,
    );
  }

  static TechnicianTask createTechnicianTask({
    String buildingName = 'Test Building',
    String? address,
    DateTime? scheduledTime,
    String status = 'pending',
    String priority = 'normal',
    String elevatorId = 'elev-1',
    String? notes,
  }) {
    return TechnicianTask(
      buildingName: buildingName,
      address: address,
      scheduledTime: scheduledTime ?? DateTime(2026, 1, 15),
      status: status,
      priority: priority,
      elevatorId: elevatorId,
      notes: notes,
    );
  }
}

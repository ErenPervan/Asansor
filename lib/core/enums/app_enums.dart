enum UserRole {
  admin('admin'),
  technician('technician'),
  customer('customer');

  final String dbValue;
  const UserRole(this.dbValue);

  static UserRole fromDb(String? value) {
    return UserRole.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => UserRole.technician,
    );
  }
}

enum ElevatorStatus {
  active('active'),
  inactive('inactive'),
  underMaintenance('under_maintenance'),
  faulty('faulty');

  final String dbValue;
  const ElevatorStatus(this.dbValue);

  static ElevatorStatus fromDb(String? value) {
    return ElevatorStatus.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => ElevatorStatus.active,
    );
  }
}

enum ScheduleStatus {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  final String dbValue;
  const ScheduleStatus(this.dbValue);

  static ScheduleStatus fromDb(String? value) {
    return ScheduleStatus.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => ScheduleStatus.pending,
    );
  }
}

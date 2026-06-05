import 'package:asansor/features/elevator/models/elevator_model.dart';

ElevatorModel? findElevator(String id, List<ElevatorModel>? elevators) {
  if (elevators == null) return null;

  for (final elevator in elevators) {
    if (elevator.id == id) return elevator;
  }

  return null;
}

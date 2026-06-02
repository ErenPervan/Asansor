import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/features/admin/models/schedule_model.dart';
import 'package:asansor/core/enums/app_enums.dart';
import '../../../helpers/test_factories.dart';

void main() {
  group('ScheduleModel Tests', () {
    test('fromJson parses complete data correctly', () {
      final scheduledDate = DateTime.utc(2026, 2, 1);
      final createdAt = DateTime.utc(2026, 1, 20);

      final json = {
        'id': 's1',
        'elevator_id': 'e1',
        'technician_id': 't1',
        'scheduled_date': scheduledDate.toIso8601String(),
        'status': 'in_progress',
        'priority': 'high',
        'task_type': 'periodic_maintenance',
        'notes': 'Bring tools',
        'created_by': 'a1',
        'created_at': createdAt.toIso8601String(),
      };

      final model = ScheduleModel.fromJson(json);

      expect(model.id, 's1');
      expect(model.elevatorId, 'e1');
      expect(model.technicianId, 't1');
      expect(model.scheduledDate, scheduledDate);
      expect(model.status, ScheduleStatus.inProgress);
      expect(model.priority, 'high');
      expect(model.taskType, 'periodic_maintenance');
      expect(model.notes, 'Bring tools');
      expect(model.createdBy, 'a1');
      expect(model.createdAt, createdAt);
    });

    test('fromJson handles nulls with defaults', () {
      final json = {'id': 's2', 'elevator_id': 'e2'};

      final model = ScheduleModel.fromJson(json);

      expect(model.id, 's2');
      expect(model.elevatorId, 'e2');
      expect(model.technicianId, '');
      expect(
        model.scheduledDate,
        DateTime.fromMillisecondsSinceEpoch(0),
      ); // Default when null
      expect(model.status, ScheduleStatus.pending); // Default
      expect(model.priority, 'normal'); // Default
      expect(model.taskType, 'manual'); // Default
      expect(model.notes, isNull);
      expect(model.createdBy, isNull);
      expect(model.createdAt, isNull);
    });

    test('toJson conditionally includes technicianId', () {
      final modelWithTech = TestFactories.createSchedule(technicianId: 't1');
      expect(modelWithTech.toJson()['technician_id'], 't1');

      final modelWithoutTech = TestFactories.createSchedule(technicianId: '');
      expect(modelWithoutTech.toJson().containsKey('technician_id'), isFalse);
    });

    test('toJson handles null notes', () {
      final model = TestFactories.createSchedule(notes: null);

      final json = model.toJson();
      expect(json.containsKey('notes'), isTrue);
      expect(json['notes'], isNull);
    });

    test('isPeriodicMaintenance getter works correctly', () {
      final periodic = TestFactories.createSchedule(
        taskType: 'periodic_maintenance',
      );
      expect(periodic.isPeriodicMaintenance, isTrue);

      final manual = TestFactories.createSchedule(taskType: 'manual');
      expect(manual.isPeriodicMaintenance, isFalse);
    });

    test('isUnassigned getter works correctly', () {
      final unassigned = TestFactories.createSchedule(technicianId: '');
      expect(unassigned.isUnassigned, isTrue);

      final assigned = TestFactories.createSchedule(technicianId: 't1');
      expect(assigned.isUnassigned, isFalse);
    });

    test('copyWith updates fields', () {
      final original = TestFactories.createSchedule(
        id: 'orig',
        status: ScheduleStatus.pending,
      );

      final updated = original.copyWith(
        status: ScheduleStatus.completed,
        priority: 'high',
      );

      expect(updated.id, 'orig');
      expect(updated.status, ScheduleStatus.completed);
      expect(updated.priority, 'high');
    });

    test('toString includes key info', () {
      final model = TestFactories.createSchedule(
        id: 's123',
        elevatorId: 'e456',
        status: ScheduleStatus.pending,
        priority: 'normal',
      );

      expect(model.toString(), contains('s123'));
      expect(model.toString(), contains('e456'));
      expect(model.toString(), contains('pending'));
    });
  });
}

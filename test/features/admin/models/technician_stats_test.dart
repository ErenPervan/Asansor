import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/features/admin/models/technician_stats.dart';
import '../../../helpers/test_factories.dart';

void main() {
  group('TechnicianTask Tests', () {
    test('isCompleted getter works correctly', () {
      final task1 = TestFactories.createTechnicianTask(status: 'completed');
      expect(task1.isCompleted, isTrue);

      final task2 = TestFactories.createTechnicianTask(status: 'pending');
      expect(task2.isCompleted, isFalse);
    });

    test('isActive getter works correctly', () {
      final pending = TestFactories.createTechnicianTask(status: 'pending');
      expect(pending.isActive, isTrue);

      final inProgress = TestFactories.createTechnicianTask(
        status: 'in_progress',
      );
      expect(inProgress.isActive, isTrue);

      final completed = TestFactories.createTechnicianTask(status: 'completed');
      expect(completed.isActive, isFalse);

      final cancelled = TestFactories.createTechnicianTask(status: 'cancelled');
      expect(cancelled.isActive, isFalse);
    });
  });

  group('TechnicianStats Tests', () {
    final profile = TestFactories.createProfile();

    test('computed fields are calculated correctly when tasks exist', () {
      final tasks = [
        TestFactories.createTechnicianTask(status: 'completed'), // 1
        TestFactories.createTechnicianTask(status: 'pending'), // 2
        TestFactories.createTechnicianTask(status: 'in_progress'), // 3
        TestFactories.createTechnicianTask(status: 'cancelled'), // 4
      ];

      final stats = TechnicianStats(
        profile: profile,
        todayTasks: tasks,
        todayCompleted:
            1, // Usually computed/queried externally, but we pass it
        monthlyCompleted: 10,
      );

      expect(stats.todayTotal, 4);
      expect(stats.todayPending, 3); // todayTotal - todayCompleted
      expect(stats.hasActiveTasks, isTrue); // Has pending and in_progress
      expect(stats.progressValue, 0.25); // 1 / 4
    });

    test(
      'progressValue is 0 when todayTotal is 0 (division by zero protection)',
      () {
        final stats = TechnicianStats(
          profile: profile,
          todayTasks: [],
          todayCompleted: 0,
          monthlyCompleted: 5,
        );

        expect(stats.todayTotal, 0);
        expect(stats.progressValue, 0.0);
        expect(stats.hasActiveTasks, isFalse);
      },
    );

    test('progressValue is clamped to 1.0 if todayCompleted > todayTotal', () {
      final tasks = [TestFactories.createTechnicianTask(status: 'completed')];

      // Technically anomalous data, but test clamp protection
      final stats = TechnicianStats(
        profile: profile,
        todayTasks: tasks,
        todayCompleted: 2,
        monthlyCompleted: 5,
      );

      expect(stats.progressValue, 1.0); // Clamped from 2/1 -> 2.0 to 1.0
    });

    test('hasActiveTasks is false when all are completed/cancelled', () {
      final tasks = [
        TestFactories.createTechnicianTask(status: 'completed'),
        TestFactories.createTechnicianTask(status: 'cancelled'),
      ];

      final stats = TechnicianStats(
        profile: profile,
        todayTasks: tasks,
        todayCompleted: 1,
        monthlyCompleted: 5,
      );

      expect(stats.hasActiveTasks, isFalse);
    });
  });
}

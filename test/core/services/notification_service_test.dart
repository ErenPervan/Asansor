import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/core/services/notification_service.dart';

void main() {
  group('NotificationService Routing Logic', () {

    test('fault_reported with fault_id should go to /fault/{id}', () {
      final data = {
        'type': 'fault_reported',
        'fault_id': '123',
      };
      expect(NotificationService.computeDestination(data), '/fault/123');
    });

    test('fault_reported without fault_id should fallback to route or /', () {
      final data1 = {'type': 'fault_reported', 'route': '/custom'};
      final data2 = {'type': 'fault_reported'};
      
      expect(NotificationService.computeDestination(data1), '/custom');
      expect(NotificationService.computeDestination(data2), '/');
    });

    test('task_assigned should go to home (/)', () {
      final data = {'type': 'task_assigned'};
      expect(NotificationService.computeDestination(data), '/');
    });

    test('task_completed should go to provided route or default calendar', () {
      final data1 = {'type': 'task_completed', 'route': '/admin/stats'};
      final data2 = {'type': 'task_completed'};
      
      expect(NotificationService.computeDestination(data1), '/admin/stats');
      expect(NotificationService.computeDestination(data2), '/admin/master-calendar');
    });

    test('maintenance_reminder with IDs should go to completion wizard', () {
      final data = {
        'type': 'maintenance_reminder',
        'schedule_id': 'sid-1',
        'elevator_id': 'eid-1',
      };
      expect(NotificationService.computeDestination(data), '/maintenance-completion/sid-1/eid-1');
    });

    test('maintenance_reminder with missing IDs should fallback to /', () {
      final data = {
        'type': 'maintenance_reminder',
        'schedule_id': 'sid-1',
      };
      expect(NotificationService.computeDestination(data), '/');
    });

    test('backward compatibility: fault_id without type', () {
      final data = {'fault_id': 'abc'};
      expect(NotificationService.computeDestination(data), '/fault/abc');
    });

    test('backward compatibility: elevator_id without type', () {
      final data = {'elevator_id': 'elev-123'};
      expect(NotificationService.computeDestination(data), '/elevator/elev-123');
    });

    test('backward compatibility: route only', () {
      final data = {'route': '/settings'};
      expect(NotificationService.computeDestination(data), '/settings');
    });

    test('unknown type and no IDs should fallback to /', () {
      final data = {'type': 'unknown_type'};
      expect(NotificationService.computeDestination(data), '/');
    });
  });
}

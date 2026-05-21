import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:asansor/core/services/auto_schedule_service.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import '../../helpers/test_mocks.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockElevatorRepository mockElevatorRepo;
  late MockScheduleRepository mockScheduleRepo;
  late AutoScheduleService service;

  setUpAll(() {
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockElevatorRepo = MockElevatorRepository();
    mockScheduleRepo = MockScheduleRepository();
    
    service = AutoScheduleService(
      mockSupabase,
      elevatorRepo: mockElevatorRepo,
      scheduleRepo: mockScheduleRepo,
    );
  });

  group('AutoScheduleService Tests', () {
    test('generateMonthlyMaintenances returns 0 when no elevators exist', () async {
      when(() => mockElevatorRepo.getAllElevators()).thenAnswer((_) async => []);

      final result = await service.generateMonthlyMaintenances(DateTime(2026, 5));

      expect(result.inserted, 0);
      expect(result.skipped, 0);
    });

    test('generateMonthlyMaintenances skips elevators without maintenanceDay', () async {
      final elevators = [
        const ElevatorModel(id: 'e1', buildingName: 'A', status: 'active'), // No maintenanceDay
      ];
      when(() => mockElevatorRepo.getAllElevators()).thenAnswer((_) async => elevators);

      final result = await service.generateMonthlyMaintenances(DateTime(2026, 5));

      expect(result.inserted, 0);
      expect(result.skipped, 0);
    });

    test('generateMonthlyMaintenances skips already scheduled elevators', () async {
      final elevators = [
        const ElevatorModel(id: 'e1', buildingName: 'A', status: 'active', maintenanceDay: 15),
      ];
      when(() => mockElevatorRepo.getAllElevators()).thenAnswer((_) async => elevators);
      when(() => mockScheduleRepo.getScheduledElevatorIdsForMonth(any())).thenAnswer((_) async => {'e1'});

      final result = await service.generateMonthlyMaintenances(DateTime(2026, 5));

      expect(result.inserted, 0);
      expect(result.skipped, 1);
    });

    test('generateMonthlyMaintenances inserts tasks for eligible elevators', () async {
      final elevators = [
        const ElevatorModel(id: 'e1', buildingName: 'A', status: 'active', maintenanceDay: 15),
        const ElevatorModel(id: 'e2', buildingName: 'B', status: 'active', maintenanceDay: 28),
      ];
      when(() => mockElevatorRepo.getAllElevators()).thenAnswer((_) async => elevators);
      when(() => mockScheduleRepo.getScheduledElevatorIdsForMonth(any())).thenAnswer((_) async => <String>{});
      
      List<Map<String, dynamic>>? capturedRows;
      when(() => mockScheduleRepo.bulkInsertPeriodicSchedules(any())).thenAnswer((invocation) async {
        capturedRows = invocation.positionalArguments.first as List<Map<String, dynamic>>;
        return capturedRows!.length;
      });

      final targetMonth = DateTime(2026, 5);
      final result = await service.generateMonthlyMaintenances(targetMonth);

      expect(result.inserted, 2);
      expect(result.skipped, 0);
      
      expect(capturedRows, isNotNull);
      expect(capturedRows!.length, 2);
      expect(capturedRows![0]['elevator_id'], 'e1');
      expect(capturedRows![0]['scheduled_date'], DateTime.utc(2026, 5, 15).toIso8601String());
      expect(capturedRows![1]['elevator_id'], 'e2');
      expect(capturedRows![1]['scheduled_date'], DateTime.utc(2026, 5, 28).toIso8601String());
    });
  });
}

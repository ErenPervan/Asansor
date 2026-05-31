import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:asansor/core/services/read_cache_service.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import '../../helpers/test_factories.dart';

void main() {
  late ReadCacheService service;

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync('hive_read_cache_test');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(elevatorsCacheBoxName);
    await Hive.openBox<String>(tasksCacheBoxName);
    await Hive.openBox<String>(checklistCacheBoxName);
    await Hive.openBox<String>(pastLogsCacheBoxName);
    await Hive.openBox<String>(faultsCacheBoxName);
  });

  setUp(() async {
    await Hive.box<String>(elevatorsCacheBoxName).clear();
    await Hive.box<String>(tasksCacheBoxName).clear();
    await Hive.box<String>(checklistCacheBoxName).clear();
    await Hive.box<String>(pastLogsCacheBoxName).clear();
    await Hive.box<String>(faultsCacheBoxName).clear();
    service = ReadCacheService();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('ReadCacheService - Elevators', () {
    test('loadElevators returns empty list initially', () {
      expect(service.hasElevators, isFalse);
      expect(service.loadElevators(), isEmpty);
    });

    test('saveElevators empty list returns empty list', () async {
      await service.saveElevators([]);
      expect(service.hasElevators, isTrue);
      expect(service.loadElevators(), isEmpty);
    });

    test('save and load elevators works correctly', () async {
      final elevators = [
        TestFactories.createElevator(id: 'e1', buildingName: 'B1'),
        TestFactories.createElevator(id: 'e2', buildingName: 'B2'),
      ];

      await service.saveElevators(elevators);

      expect(service.hasElevators, isTrue);
      final loaded = service.loadElevators();

      expect(loaded.length, 2);
      expect(loaded[0].id, 'e1');
      expect(loaded[1].buildingName, 'B2');
    });

    test('loadElevators returns empty on bad JSON', () async {
      await Hive.box<String>(elevatorsCacheBoxName).put('all', 'not_json');
      expect(service.loadElevators(), isEmpty);
    });
  });

  group('ReadCacheService - Tasks (per user)', () {
    test('loadMyTasks returns empty list initially', () {
      expect(service.hasMyTasks('u1'), isFalse);
      expect(service.loadMyTasks('u1'), isEmpty);
    });

    test('saveMyTasks empty userId does nothing', () async {
      await service.saveMyTasks('', [TestFactories.createSchedule()]);
      expect(service.hasMyTasks(''), isFalse);
      expect(service.loadMyTasks(''), isEmpty);
    });

    test('save and load tasks works correctly', () async {
      final tasks = [
        TestFactories.createSchedule(id: 't1', elevatorId: 'e1'),
        TestFactories.createSchedule(id: 't2', elevatorId: 'e2'),
      ];

      await service.saveMyTasks('user_x', tasks);

      expect(service.hasMyTasks('user_x'), isTrue);
      expect(service.hasMyTasks('other_user'), isFalse);

      final loaded = service.loadMyTasks('user_x');

      expect(loaded.length, 2);
      expect(loaded[0].id, 't1');
      expect(loaded[1].elevatorId, 'e2');
    });
  });

  group('ReadCacheService - Past Logs', () {
    test('savePastLogs empty elevatorId does nothing', () async {
      await service.savePastLogs('', [TestFactories.createMaintenanceLog()]);
      expect(
        service.loadPastLogs('', (j) => MaintenanceLogModel.fromJson(j)),
        isEmpty,
      );
    });

    test('save and load past logs works correctly', () async {
      final logs = [
        TestFactories.createMaintenanceLog(
          id: 'l1',
          elevatorId: 'e1',
          notes: 'Log 1',
        ),
      ];

      await service.savePastLogs('e1', logs);

      final loaded = service.loadPastLogs(
        'e1',
        (json) => MaintenanceLogModel.fromJson(json),
      );

      expect(loaded.length, 1);
      expect((loaded[0] as MaintenanceLogModel).notes, 'Log 1');
    });
  });

  group('ReadCacheService - Faults', () {
    test('save and load faults works correctly', () async {
      final faults = [
        TestFactories.createFaultReport(id: 'f1', description: 'Fault 1'),
      ];

      await service.saveFaults(faults);

      final loaded = service.loadFaults(
        (json) => FaultReportModel.fromJson(json),
      );

      expect(loaded.length, 1);
      expect((loaded[0] as FaultReportModel).description, 'Fault 1');
    });
  });
}

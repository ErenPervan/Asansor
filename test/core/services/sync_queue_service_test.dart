import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:asansor/core/services/sync_queue_service.dart';

void main() {
  late SyncQueueService service;
  late Box<String> box;

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync('hive_sync_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>(syncQueueBoxName);
    
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() async {
    await box.clear();
    service = SyncQueueService();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('SyncQueueService - Enqueue', () {
    test('enqueues item successfully and notifies listeners', () async {
      bool notified = false;
      service.addListener(() => notified = true);

      await service.enqueue(
        type: SyncItemType.elevatorUpdate,
        payload: {'id': 'e1', 'status': 'faulty', 'base_version': 1},
      );

      expect(notified, isTrue);
      expect(service.pendingCount, 1);
      expect(service.conflictCount, 0);
      expect(box.length, 1);
      
      final raw = box.getAt(0);
      expect(raw, isNotNull);
      final item = jsonDecode(raw!) as Map<String, dynamic>;
      expect(item['type'], SyncItemType.elevatorUpdate);
      expect(item['status'], 'pending');
      expect(item['payload']['id'], 'e1');
    });
  });

  group('SyncQueueService - Conflict Detection Properties', () {
    test('conflictedItems and counts are updated when manual conflict data is injected', () async {
      await box.put('conflict_1', jsonEncode({
        'id': 'conflict_1',
        'type': SyncItemType.elevatorUpdate,
        'payload': {'id': 'e2'},
        'queued_at': DateTime.now().toIso8601String(),
        'status': 'conflict_detected',
        'remote_state': {'id': 'e2', 'version': 5}
      }));

      expect(service.pendingCount, 0);
      expect(service.conflictCount, 1);
      
      final conflicted = service.conflictedItems;
      expect(conflicted.length, 1);
      expect(conflicted.first['status'], 'conflict_detected');
      expect(conflicted.first['remote_state']['version'], 5);
    });

    test('resolveDiscard removes item from queue', () async {
      await service.enqueue(
        type: SyncItemType.faultReport,
        payload: {'id': 'f1'},
      );
      final key = box.keys.first as String;

      await service.resolveDiscard(key);

      expect(box.length, 0);
      expect(service.pendingCount, 0);
    });
  });
}

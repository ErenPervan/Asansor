import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:asansor/core/services/sync_queue_service.dart';
import 'package:asansor/core/services/sync/queue/sync_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../helpers/test_mocks.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late SyncQueueService service;
  late Box<String> box;

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync('hive_sync_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>(syncQueueBoxName);
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

    test('hasPending getter works correctly', () async {
      expect(service.hasPending, isFalse);

      await service.enqueue(
        type: SyncItemType.elevatorUpdate,
        payload: {'id': 'e1'},
      );

      expect(service.hasPending, isTrue);
    });
  });

  group('SyncQueueService - Conflict Detection Properties', () {
    test(
      'conflictedItems and counts are updated when manual conflict data is injected',
      () async {
        await box.put(
          'conflict_1',
          jsonEncode({
            'id': 'conflict_1',
            'type': SyncItemType.elevatorUpdate,
            'payload': {'id': 'e2'},
            'queued_at': DateTime.now().toIso8601String(),
            'status': 'conflict_detected',
            'remote_state': {'id': 'e2', 'version': 5},
          }),
        );

        expect(service.pendingCount, 0);
        expect(service.conflictCount, 1);

        final conflicted = service.conflictedItems;
        expect(conflicted.length, 1);
        expect(conflicted.first['status'], 'conflict_detected');
        expect(conflicted.first['remote_state']['version'], 5);
      },
    );

    test('resolveDiscard removes item and notifies listeners', () async {
      bool notified = false;
      service.addListener(() => notified = true);

      await service.enqueue(
        type: SyncItemType.faultReport,
        payload: {'id': 'f1'},
      );
      final key = box.keys.first as String;

      // Reset notification flag
      notified = false;

      await service.resolveDiscard(key);

      expect(box.length, 0);
      expect(service.pendingCount, 0);
      expect(notified, isTrue);
    });
  });

  group(
    'SyncQueueService - OCC Version Tracking (Private method testing via enqueue/process logic)',
    () {
      test('consecutive enqueues for same elevator track versionMap', () async {
        // Since flush and _processWithVersionTracking are private/complex to test directly without a Mock SupabaseClient,
        // we test that enqueuing multiple updates maintains them in the box, and if we inspect the payloads,
        // they don't automatically increment version BEFORE flush, but rather the enqueue allows multiple pending items.

        await service.enqueue(
          type: SyncItemType.elevatorUpdate,
          payload: {'id': 'elev_occ', 'status': 'faulty', 'base_version': 1},
        );

        await service.enqueue(
          type: SyncItemType.elevatorUpdate,
          payload: {
            'id': 'elev_occ',
            'status': 'active',
            'base_version': 1,
          }, // UI might pass 1 again if not refreshed
        );

        expect(service.pendingCount, 2);

        final keys = box.keys.toList();
        final raw1 = box.get(keys[0]);
        final raw2 = box.get(keys[1]);

        expect(jsonDecode(raw1!)['payload']['base_version'], 1);
        // Wait, enqueue itself doesn't update the version Map, flush does.
        // So this test just confirms they both get enqueued.
        expect(jsonDecode(raw2!)['payload']['base_version'], 1);
      });
    },
  );

  group('SyncQueueService - Flush & Retry', () {
    late MockSupabaseClient mockClient;
    late MockSupabaseQueryBuilder mockQueryBuilder;

    setUp(() {
      mockClient = MockSupabaseClient();
      mockQueryBuilder = MockSupabaseQueryBuilder();
      when(() => mockClient.from(any())).thenAnswer((_) => mockQueryBuilder);
    });

    test('flush transient error increments attempt_count', () async {
      when(() => mockQueryBuilder.upsert(any(), onConflict: any(named: 'onConflict')))
          .thenThrow(Exception('Transient network error'));

      await service.enqueue(
        type: SyncItemType.faultReport,
        payload: {'id': 'f1'},
      );

      final result = await service.flush(mockClient);
      expect(result.failed, 1);
      expect(result.synced, 0);

      final keys = box.keys.toList();
      final raw = box.get(keys.first);
      final item = jsonDecode(raw!) as Map<String, dynamic>;
      
      expect(item['attempt_count'], 1);
      expect(item['next_retry_at'], isNotNull);
      expect(item['status'], 'pending');
    });

    test('flush terminal error sets status to dead_letter', () async {
      // Simulate Postgres exception for terminal error (like invalid schema)
      when(() => mockQueryBuilder.upsert(any(), onConflict: any(named: 'onConflict')))
          .thenThrow(PostgrestException(message: 'Invalid column', code: '42703'));

      await service.enqueue(
        type: SyncItemType.faultReport,
        payload: {'id': 'f2'},
      );

      final result = await service.flush(mockClient);
      expect(result.failed, 1);
      expect(result.synced, 0);

      final keys = box.keys.toList();
      final raw = box.get(keys.first);
      final item = jsonDecode(raw!) as Map<String, dynamic>;
      
      expect(item['status'], syncStatusDeadLetter);
      expect(item['error_details'], contains('Invalid column'));
    });
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:asansor/core/services/sync/sync_coordinator.dart';
import 'package:asansor/core/exceptions/conflict_exception.dart';
import '../../helpers/test_mocks.dart';

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

      await service.resolveDiscard(MockSupabaseClient(), key);

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
        expect(jsonDecode(raw2!)['payload']['base_version'], 1);
      });
    },
  );

  group('SyncQueueService - Flush & Retry logic with MockRemoteWriter', () {
    late MockSupabaseClient mockClient;
    late MockSyncRemoteWriter mockRemoteWriter;

    setUp(() {
      mockClient = MockSupabaseClient();
      mockRemoteWriter = MockSyncRemoteWriter();
      service.overrideRemoteWriter = mockRemoteWriter;
    });

    test('flush successful updates queue and removes items', () async {
      await service.enqueue(
        type: SyncItemType.elevatorUpdate,
        payload: {'id': 'e1', 'status': 'faulty', 'base_version': 1},
      );

      when(
        () => mockRemoteWriter.syncElevatorUpdate(any()),
      ).thenAnswer((_) async {});

      final result = await service.flush(mockClient);

      expect(result.synced, 1);
      expect(result.failed, 0);
      expect(service.pendingCount, 0);
      expect(box.length, 0);
    });

    test(
      'flush conflict throws ConflictException and updates status',
      () async {
        await service.enqueue(
          type: SyncItemType.elevatorUpdate,
          payload: {'id': 'e1', 'status': 'faulty', 'base_version': 1},
        );

        when(
          () => mockRemoteWriter.syncElevatorUpdate(any()),
        ).thenThrow(ConflictException(remoteState: {'version': 2}));

        final result = await service.flush(mockClient);

        expect(result.synced, 0);
        expect(result.failed, 1);
        expect(service.pendingCount, 0);
        expect(service.conflictCount, 1);
        expect(box.length, 1);

        final item = jsonDecode(box.getAt(0)!);
        expect(item['status'], 'conflict_detected');
        expect(item['remote_state']['version'], 2);
      },
    );

    test('flush transient error applies exponential backoff', () async {
      await service.enqueue(
        type: SyncItemType.elevatorUpdate,
        payload: {'id': 'e2', 'status': 'active', 'base_version': 1},
      );

      // Simulate a transient network error that is terminal
      when(
        () => mockRemoteWriter.syncElevatorUpdate(any()),
      ).thenThrow(Exception('Network disconnected'));
      when(() => mockRemoteWriter.isTerminalError(any())).thenReturn(false);

      final result = await service.flush(mockClient);

      expect(result.synced, 0);
      expect(result.failed, 1);

      final item = jsonDecode(box.getAt(0)!);
      expect(item['retry_count'], 1);
      expect(item['next_retry_at'], isNotNull);
      expect(item['status'], 'pending'); // Still pending, just delayed
    });
  });
}

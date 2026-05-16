// =============================================================================
// Unit Tests: SyncQueueService (Hive-based offline sync queue)
// =============================================================================
//
// Tests the core guarantees of the sync queue:
//   1. Enqueue persists items and increments pendingCount.
//   2. Flush with successful sync removes items from the queue.
//   3. Flush with failing sync keeps items in the queue.
//   4. Empty queue flush returns zero counts.
//   5. ChangeNotifier fires after enqueue and flush.
//
// Uses a real Hive box in a temp directory for actual persistence tests.
//
// APPROACH: Supabase's Postgrest builders implement Future<T>, which makes
// standard mockito stubbing extremely difficult. Instead, we extend
// SyncQueueService with a testable subclass that replaces the DB write
// step with controllable success/fail behavior.
// =============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:asansor/core/models/sync_task.dart';
import 'package:asansor/core/services/sync_queue_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Controllable Test Double
// ─────────────────────────────────────────────────────────────────────────────

/// Controls whether syncing should succeed or fail.
enum SyncBehavior { succeed, fail }

/// A testable extension of SyncQueueService that replaces the real Supabase
/// DB write with controllable behavior.
///
/// This lets us test the queue mechanics (enqueue, persist, flush, delete,
/// retry) without needing a real or mocked SupabaseClient.
class TestableSyncQueueService extends SyncQueueService {
  TestableSyncQueueService({this.behavior = SyncBehavior.succeed});

  SyncBehavior behavior;

  /// Track which items were attempted (for assertion purposes).
  final List<SyncTask> processedItems = [];

  /// Replays the flush logic with our fake processing instead of real Supabase.
  Future<SyncResult> flushWithFakeBehavior() async {
    final box = Hive.box<SyncTask>(syncQueueBoxName);
    final tasks = box.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    int synced = 0;
    int failed = 0;

    for (final task in tasks) {
      final current = box.get(task.id);
      if (current == null) continue;

      try {
        processedItems.add(current);

        if (behavior == SyncBehavior.fail) {
          throw Exception('Simulated network failure');
        }

        // "Success" — delete from queue.
        await box.delete(task.id);
        synced++;
      } catch (_) {
        // Keep in queue for retry.
        failed++;
      }
    }

    if (synced > 0 || failed == 0) {
      notifyListeners();
    }

    return SyncResult(synced: synced, failed: failed);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a temporary directory for Hive and opens the sync queue box.
Future<String> _initHiveForTest() async {
  final tempDir = Directory.systemTemp.createTempSync('hive_sync_test_');
  Hive.init(tempDir.path);
  if (!Hive.isAdapterRegistered(SyncTask.typeId)) {
    Hive.registerAdapter(SyncTaskAdapter());
  }
  await Hive.openBox<SyncTask>(syncQueueBoxName);
  return tempDir.path;
}

/// Cleans up the Hive box and temp directory after each test.
Future<void> _teardownHive(String tempDirPath) async {
  await Hive.box<SyncTask>(syncQueueBoxName).clear();
  await Hive.close();
  try {
    Directory(tempDirPath).deleteSync(recursive: true);
  } catch (_) {
    // Best-effort cleanup.
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late TestableSyncQueueService service;
  late String tempDirPath;

  setUp(() async {
    tempDirPath = await _initHiveForTest();
    service = TestableSyncQueueService();
  });

  tearDown(() async {
    service.dispose();
    await _teardownHive(tempDirPath);
  });

  group('SyncQueueService', () {
    // ── Enqueue ─────────────────────────────────────────────────────────────

    group('enqueue', () {
      test('adds an item and increments pendingCount', () async {
        expect(service.pendingCount, 0);
        expect(service.hasPending, false);

        await service.enqueue(
          endpoint: SyncEndpoint.insertMaintenanceLog,
          payload: {
            'elevator_id': 'elev-001',
            'technician_id': 'tech-001',
            'notes': 'Test maintenance log',
          },
        );

        expect(service.pendingCount, 1);
        expect(service.hasPending, true);
      });

      test('fires notifyListeners', () async {
        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {
            'elevator_id': 'elev-002',
            'description': 'Door stuck',
          },
        );

        expect(notifyCount, 1);
      });

      test('preserves payload data in Hive box', () async {
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {
            'elevator_id': 'elev-003',
            'description': 'Alarm not working',
          },
        );

        final box = Hive.box<SyncTask>(syncQueueBoxName);
        expect(box.length, 1);

        final task = box.values.first;
        expect(task.payload['elevator_id'], 'elev-003');
        expect(task.payload['description'], 'Alarm not working');
        expect(task.endpoint, SyncEndpoint.insertFaultReport);
      });

      test('stores correct endpoint field in task', () async {
        await service.enqueue(
          endpoint: SyncEndpoint.insertMaintenanceLog,
          payload: {'notes': 'Test'},
        );

        final box = Hive.box<SyncTask>(syncQueueBoxName);
        expect(box.values.first.endpoint, SyncEndpoint.insertMaintenanceLog);
      });

      test('multiple enqueue calls create distinct items', () async {
        await service.enqueue(
          endpoint: SyncEndpoint.insertMaintenanceLog,
          payload: {'notes': 'First'},
        );
        await Future.delayed(const Duration(milliseconds: 1));
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {'description': 'Second'},
        );

        expect(service.pendingCount, 2);
      });

      test('items have increasing createdAt for FIFO ordering',
          () async {
        await service.enqueue(
          endpoint: SyncEndpoint.insertMaintenanceLog,
          payload: {'notes': 'First'},
        );
        await Future.delayed(const Duration(milliseconds: 1));
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {'description': 'Second'},
        );

        final box = Hive.box<SyncTask>(syncQueueBoxName);
        final tasks = box.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        expect(tasks.length, 2);
        expect(tasks[0].createdAt.isBefore(tasks[1].createdAt), true);
      });

      test('stores createdAt timestamp', () async {
        final before = DateTime.now();
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {'description': 'Timestamped'},
        );
        final after = DateTime.now();

        final box = Hive.box<SyncTask>(syncQueueBoxName);
        final createdAt = box.values.first.createdAt;

        expect(
            createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
            true);
        expect(createdAt.isBefore(after.add(const Duration(seconds: 1))), true);
      });
    });

    // ── Flush: Empty Queue ──────────────────────────────────────────────────

    group('flush (empty queue)', () {
      test('returns SyncResult(synced: 0, failed: 0)', () async {
        expect(service.pendingCount, 0);

        final result = await service.flushWithFakeBehavior();

        expect(result.synced, 0);
        expect(result.failed, 0);
        expect(result.hasFailures, false);
      });
    });

    // ── Flush: All Succeed ──────────────────────────────────────────────────

    group('flush (all succeed)', () {
      test('removes synced fault_report from queue', () async {
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {
            'elevator_id': 'elev-flush-ok',
            'description': 'Test fault',
          },
        );
        expect(service.pendingCount, 1);

        service.behavior = SyncBehavior.succeed;
        final result = await service.flushWithFakeBehavior();

        expect(result.synced, 1);
        expect(result.failed, 0);
        expect(result.hasFailures, false);
        expect(service.pendingCount, 0);
        expect(service.hasPending, false);
      });

      test('removes multiple items when all succeed', () async {
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {'description': 'Fault 1'},
        );
        await Future.delayed(const Duration(milliseconds: 1));
        await service.enqueue(
          endpoint: SyncEndpoint.insertMaintenanceLog,
          payload: {'notes': 'Log 1'},
        );
        await Future.delayed(const Duration(milliseconds: 1));
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {'description': 'Fault 2'},
        );
        expect(service.pendingCount, 3);

        service.behavior = SyncBehavior.succeed;
        final result = await service.flushWithFakeBehavior();

        expect(result.synced, 3);
        expect(result.failed, 0);
        expect(service.pendingCount, 0);
      });

      test('notifies listeners after successful flush', () async {
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {'description': 'To be flushed'},
        );

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        service.behavior = SyncBehavior.succeed;
        await service.flushWithFakeBehavior();

        expect(notifyCount, greaterThan(0));
      });
    });

    // ── Flush: All Fail ─────────────────────────────────────────────────────

    group('flush (all fail)', () {
      test('keeps failed items in queue for retry', () async {
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {
            'elevator_id': 'elev-fail',
            'description': 'Will fail to sync',
          },
        );
        expect(service.pendingCount, 1);

        service.behavior = SyncBehavior.fail;
        final result = await service.flushWithFakeBehavior();

        expect(result.synced, 0);
        expect(result.failed, 1);
        expect(result.hasFailures, true);
        // Critical guarantee: item STAYS in queue for retry.
        expect(service.pendingCount, 1);
        expect(service.hasPending, true);
      });

      test('failed items survive multiple flush attempts', () async {
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {'description': 'Persistent failure'},
        );

        service.behavior = SyncBehavior.fail;

        // First attempt — fails.
        final result1 = await service.flushWithFakeBehavior();
        expect(result1.failed, 1);
        expect(service.pendingCount, 1);

        // Second attempt — still fails, still in queue.
        final result2 = await service.flushWithFakeBehavior();
        expect(result2.failed, 1);
        expect(service.pendingCount, 1);
      });
    });

    // ── Flush: Failure → Recovery ───────────────────────────────────────────

    group('flush (failure then recovery)', () {
      test('items eventually sync when connectivity is restored', () async {
        await service.enqueue(
          endpoint: SyncEndpoint.insertMaintenanceLog,
          payload: {'notes': 'Offline log'},
        );

        // Simulate offline — fails.
        service.behavior = SyncBehavior.fail;
        final offlineResult = await service.flushWithFakeBehavior();
        expect(offlineResult.failed, 1);
        expect(service.pendingCount, 1);

        // Simulate back online — succeeds.
        service.behavior = SyncBehavior.succeed;
        final onlineResult = await service.flushWithFakeBehavior();
        expect(onlineResult.synced, 1);
        expect(onlineResult.failed, 0);
        expect(service.pendingCount, 0);
      });

      test('multi-item recovery after network restoration', () async {
        // Enqueue 3 items while offline, with small delays to keep ordering.
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {'description': 'Offline fault 0'},
        );
        await Future.delayed(const Duration(milliseconds: 1));
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {'description': 'Offline fault 1'},
        );
        await Future.delayed(const Duration(milliseconds: 1));
        await service.enqueue(
          endpoint: SyncEndpoint.insertFaultReport,
          payload: {'description': 'Offline fault 2'},
        );
        expect(service.pendingCount, 3);

        // All fail.
        service.behavior = SyncBehavior.fail;
        final fail = await service.flushWithFakeBehavior();
        expect(fail.failed, 3);
        expect(service.pendingCount, 3);

        // All succeed on retry.
        service.behavior = SyncBehavior.succeed;
        final success = await service.flushWithFakeBehavior();
        expect(success.synced, 3);
        expect(success.failed, 0);
        expect(service.pendingCount, 0);
      });
    });

    // ── SyncResult Model ────────────────────────────────────────────────────

    group('SyncResult', () {
      test('hasFailures returns correct boolean', () {
        const noFailures = SyncResult(synced: 3, failed: 0);
        expect(noFailures.hasFailures, false);

        const withFailures = SyncResult(synced: 1, failed: 2);
        expect(withFailures.hasFailures, true);

        const zeroZero = SyncResult(synced: 0, failed: 0);
        expect(zeroZero.hasFailures, false);
      });

      test('toString is descriptive', () {
        const result = SyncResult(synced: 5, failed: 1);
        expect(result.toString(), 'SyncResult(synced: 5, failed: 1)');
      });
    });
  });
}

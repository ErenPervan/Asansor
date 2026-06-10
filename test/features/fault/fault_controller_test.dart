import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/core/services/sync/sync_coordinator.dart';
import 'package:asansor/features/fault/providers/fault_providers.dart';

import '../../helpers/provider_test_utils.dart';
import '../../helpers/test_mocks.dart';

void main() {
  late SpySyncQueueService spySyncQueue;
  late MockSupabaseClient mockSupabaseClient;
  late MockFaultRepository mockRepo;
  late FakeReadCacheService fakeCache;

  setUp(() {
    spySyncQueue = SpySyncQueueService();
    mockSupabaseClient = MockSupabaseClient();
    mockRepo = MockFaultRepository();
    fakeCache = FakeReadCacheService();

    // Stub mockRepo methods to return empty lists to avoid null errors when providers are read
    when(() => mockRepo.getAllActiveFaults()).thenAnswer((_) async => []);
  });

  group('FaultController - reportFault', () {
    test('offline -> enqueue çağrılır, flush çağrılmaz', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          syncQueueServiceProvider.overrideWith((ref) => spySyncQueue),
          supabaseClientProvider.overrideWithValue(mockSupabaseClient),
          faultRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
        ],
      );

      final controller = container.read(faultControllerProvider.notifier);
      await controller.reportFault(elevatorId: 'e1', description: 'Test error');

      expect(spySyncQueue.enqueuedItems.length, 1);
      expect(
        spySyncQueue.enqueuedItems.first['type'],
        SyncItemType.faultReport,
      );
      expect(spySyncQueue.flushCallCount, 0);

      final state = container.read(faultControllerProvider);
      expect(state.value, isNotNull);
      expect(state.value!.isOfflineQueued, isTrue);
    });

    test('online başarı -> enqueue + flush çağrılır', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          syncQueueServiceProvider.overrideWith((ref) => spySyncQueue),
          supabaseClientProvider.overrideWithValue(mockSupabaseClient),
          faultRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
        ],
      );

      final controller = container.read(faultControllerProvider.notifier);
      await controller.reportFault(elevatorId: 'e1', description: 'Test error');

      expect(spySyncQueue.enqueuedItems.length, 1);
      expect(
        spySyncQueue.enqueuedItems.first['type'],
        SyncItemType.faultReport,
      );
      expect(spySyncQueue.flushCallCount, 1);

      final state = container.read(faultControllerProvider);
      expect(state.value, isNotNull);
      expect(state.value!.isOfflineQueued, isFalse);
    });

    test(
      'online hata -> flush exception fırlatsa bile state AsyncData olur',
      () async {
        spySyncQueue.shouldThrowOnFlush = true;

        final container = createContainer(
          overrides: [
            isOnlineProvider.overrideWithValue(true),
            syncQueueServiceProvider.overrideWith((ref) => spySyncQueue),
            supabaseClientProvider.overrideWithValue(mockSupabaseClient),
            faultRepositoryProvider.overrideWithValue(mockRepo),
            readCacheServiceProvider.overrideWithValue(fakeCache),
          ],
        );

        final controller = container.read(faultControllerProvider.notifier);

        try {
          await controller.reportFault(
            elevatorId: 'e1',
            description: 'Test error',
          );
        } catch (_) {}

        expect(spySyncQueue.enqueuedItems.length, 1);
        expect(spySyncQueue.flushCallCount, 1);
      },
    );
  });

  group('FaultUpdateController - resolve', () {
    test('offline -> enqueue çağrılır, flush çağrılmaz', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          syncQueueServiceProvider.overrideWith((ref) => spySyncQueue),
          supabaseClientProvider.overrideWithValue(mockSupabaseClient),
          faultRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
        ],
      );

      final controller = container.read(faultUpdateControllerProvider.notifier);
      final success = await controller.resolve('f1', resolutionNotes: 'Fixed');

      expect(success, isTrue);
      expect(spySyncQueue.enqueuedItems.length, 1);
      expect(
        spySyncQueue.enqueuedItems.first['type'],
        SyncItemType.faultResolve,
      );
      expect(spySyncQueue.flushCallCount, 0);
    });

    test('online başarı -> enqueue ve flush çağrılır', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          syncQueueServiceProvider.overrideWith((ref) => spySyncQueue),
          supabaseClientProvider.overrideWithValue(mockSupabaseClient),
          faultRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
        ],
      );

      final controller = container.read(faultUpdateControllerProvider.notifier);
      final success = await controller.resolve('f1');

      expect(success, isTrue);
      expect(spySyncQueue.enqueuedItems.length, 1);
      expect(
        spySyncQueue.enqueuedItems.first['type'],
        SyncItemType.faultResolve,
      );
      expect(spySyncQueue.flushCallCount, 1);
    });
  });

  group('FaultUpdateController - reopen', () {
    test('offline -> enqueue çağrılır, flush çağrılmaz', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          syncQueueServiceProvider.overrideWith((ref) => spySyncQueue),
          supabaseClientProvider.overrideWithValue(mockSupabaseClient),
          faultRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
        ],
      );

      final controller = container.read(faultUpdateControllerProvider.notifier);
      final success = await controller.reopen('f1');

      expect(success, isTrue);
      expect(spySyncQueue.enqueuedItems.length, 1);
      expect(
        spySyncQueue.enqueuedItems.first['type'],
        SyncItemType.faultReopen,
      );
      expect(spySyncQueue.flushCallCount, 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/core/services/sync/sync_coordinator.dart';
import 'package:asansor/features/maintenance/providers/maintenance_providers.dart';
import 'package:asansor/features/maintenance/repositories/maintenance_repository.dart';
import 'package:asansor/core/services/read_cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/provider_test_utils.dart';
import '../../helpers/test_mocks.dart';

void main() {
  late SpySyncQueueService spySyncQueue;
  late MockSupabaseClient mockSupabaseClient;
  late MockMaintenanceRepository mockRepo;
  late FakeReadCacheService fakeCache;

  setUp(() {
    spySyncQueue = SpySyncQueueService();
    mockSupabaseClient = MockSupabaseClient();
    mockRepo = MockMaintenanceRepository();
    fakeCache = FakeReadCacheService();

    when(() => mockRepo.getAllPendingLogs()).thenAnswer((_) async => []);
  });

  group('MaintenanceController - addLog', () {
    test('offline -> enqueue çağrılır, flush çağrılmaz', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          syncQueueServiceProvider.overrideWith((ref) => spySyncQueue),
          supabaseClientProvider.overrideWithValue(mockSupabaseClient),
          maintenanceRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
        ],
      );

      final controller = container.read(maintenanceControllerProvider.notifier);
      await controller.addLog(
        elevatorId: 'e1',
        technicianId: 'tech1',
        maintenanceDate: DateTime.now(),
        notes: 'Test notes',
        checklist: {'test': true},
        photos: [],
      );

      expect(spySyncQueue.enqueuedItems.length, 1);
      expect(
        spySyncQueue.enqueuedItems.first['type'],
        SyncItemType.maintenanceLog,
      );
      expect(spySyncQueue.flushCallCount, 0);

      final state = container.read(maintenanceControllerProvider);
      expect(state.value, isNotNull);
      expect(state.value!.isOfflineQueued, isTrue);
    });

    test('online başarı -> enqueue + flush çağrılır', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          syncQueueServiceProvider.overrideWith((ref) => spySyncQueue),
          supabaseClientProvider.overrideWithValue(mockSupabaseClient),
          maintenanceRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
        ],
      );

      final controller = container.read(maintenanceControllerProvider.notifier);
      await controller.addLog(
        elevatorId: 'e1',
        technicianId: 'tech1',
        maintenanceDate: DateTime.now(),
        notes: 'Test notes',
        checklist: {'test': true},
        photos: [],
      );

      expect(spySyncQueue.enqueuedItems.length, 1);
      expect(
        spySyncQueue.enqueuedItems.first['type'],
        SyncItemType.maintenanceLog,
      );
      expect(spySyncQueue.flushCallCount, 1);

      final state = container.read(maintenanceControllerProvider);
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
            maintenanceRepositoryProvider.overrideWithValue(mockRepo),
            readCacheServiceProvider.overrideWithValue(fakeCache),
          ],
        );

        final controller = container.read(
          maintenanceControllerProvider.notifier,
        );

        try {
          await controller.addLog(
            elevatorId: 'e1',
            technicianId: 'tech1',
            maintenanceDate: DateTime.now(),
            notes: 'Test notes',
            checklist: {'test': true},
            photos: [],
          );
        } catch (_) {}

        expect(spySyncQueue.enqueuedItems.length, 1);
        expect(spySyncQueue.flushCallCount, 1);
      },
    );
  });
}

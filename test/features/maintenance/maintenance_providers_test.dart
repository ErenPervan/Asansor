import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/features/maintenance/providers/maintenance_providers.dart';


import '../../helpers/provider_test_utils.dart';
import '../../helpers/test_mocks.dart';
import '../../helpers/test_factories.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDateTime());
  });

  group('pendingMaintenanceProvider', () {
    late MockMaintenanceRepository mockRepo;
    late MockReadCacheService mockCache;
    late MockSyncQueueService mockQueue;

    setUp(() {
      mockRepo = MockMaintenanceRepository();
      mockCache = MockReadCacheService();
      mockQueue = MockSyncQueueService();
      when(() => mockQueue.pendingItemsOfType(any())).thenReturn([]);
      when(() => mockCache.loadPendingMaintenance()).thenReturn([]);
      when(() => mockCache.savePendingMaintenance(any())).thenAnswer((_) async => {});
    });

    test('offline → cache boşsa boş liste döner', () async {
      when(() => mockCache.loadPendingMaintenance()).thenReturn([]);
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          maintenanceRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(mockCache),
          syncQueueServiceProvider.overrideWith((ref) => mockQueue),
        ],
      );

      final result = await container.read(pendingMaintenanceProvider.future);
      expect(result, isEmpty);
      verifyNever(() => mockRepo.getAllPendingLogs());
    });

    test(
      'online başarı → repository çağrılır ve bekleyen loglar döner',
      () async {
        final logs = [
          TestFactories.createMaintenanceLog(id: 'l1', isApproved: false),
          TestFactories.createMaintenanceLog(id: 'l2', isApproved: false),
        ];
        when(() => mockRepo.getAllPendingLogs()).thenAnswer((_) async => logs);

        final container = createContainer(
          overrides: [
            isOnlineProvider.overrideWithValue(true),
            maintenanceRepositoryProvider.overrideWithValue(mockRepo),
            readCacheServiceProvider.overrideWithValue(mockCache),
            syncQueueServiceProvider.overrideWith((ref) => mockQueue),
          ],
        );

        final result = await container.read(pendingMaintenanceProvider.future);
        expect(result.length, 2);
        expect(result.every((l) => !l.isApproved), isTrue);
        verify(() => mockRepo.getAllPendingLogs()).called(1);
      },
    );

    test('online hata + cache boşsa exception rethrow olur', () async {
      when(
        () => mockRepo.getAllPendingLogs(),
      ).thenThrow(Exception('Ağ bağlantısı kesildi'));

      when(() => mockCache.loadPendingMaintenance()).thenReturn([]);

      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          maintenanceRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(mockCache),
          syncQueueServiceProvider.overrideWith((ref) => mockQueue),
        ],
      );

      await expectLater(
        container.read(pendingMaintenanceProvider.future),
        throwsA(isA<Exception>()),
      );
    });

    test('online hata + cache dolu ise cache doner', () async {
      final cachedLogs = [
        TestFactories.createMaintenanceLog(id: 'c1', isApproved: false),
      ];
      when(() => mockRepo.getAllPendingLogs()).thenThrow(Exception('Ağ hatası'));
      when(() => mockCache.loadPendingMaintenance()).thenReturn(cachedLogs);

      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          maintenanceRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(mockCache),
          syncQueueServiceProvider.overrideWith((ref) => mockQueue),
        ],
      );

      final result = await container.read(pendingMaintenanceProvider.future);
      expect(result.length, 1);
      expect(result.every((f) => !f.isApproved), isTrue);
      verify(() => mockRepo.getAllPendingLogs()).called(1);
    });
  });

  group('completedTodayCountProvider', () {
    late MockMaintenanceRepository mockRepo;
    late MockReadCacheService mockCache;
    late MockSyncQueueService mockQueue;

    setUp(() {
      mockRepo = MockMaintenanceRepository();
      mockCache = MockReadCacheService();
      mockQueue = MockSyncQueueService();
      when(() => mockCache.loadCompletedTodayCount()).thenReturn(0);
      when(() => mockCache.saveCompletedTodayCount(any())).thenAnswer((_) async => {});
    });

    test('offline → cache boşsa 0 döner', () async {
      when(() => mockCache.loadCompletedTodayCount()).thenReturn(0);
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          maintenanceRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(mockCache),
          syncQueueServiceProvider.overrideWith((ref) => mockQueue),
        ],
      );

      final result = await container.read(completedTodayCountProvider.future);
      expect(result, 0);
      verifyNever(() => mockRepo.getCompletedTodayCount());
    });

    test('online başarı → repository sayısı döner', () async {
      when(() => mockRepo.getCompletedTodayCount()).thenAnswer((_) async => 7);

      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          maintenanceRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(mockCache),
          syncQueueServiceProvider.overrideWith((ref) => mockQueue),
        ],
      );

      final result = await container.read(completedTodayCountProvider.future);
      expect(result, 7);
      verify(() => mockRepo.getCompletedTodayCount()).called(1);
    });
  });
}

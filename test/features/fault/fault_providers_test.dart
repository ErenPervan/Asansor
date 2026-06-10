import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/features/fault/providers/fault_providers.dart';

import '../../helpers/provider_test_utils.dart';
import '../../helpers/test_mocks.dart';
import '../../helpers/test_factories.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDateTime());
  });

  group('allFaultsProvider', () {
    late MockFaultRepository mockRepo;
    late FakeReadCacheService fakeCache;

    setUp(() {
      mockRepo = MockFaultRepository();
      fakeCache = FakeReadCacheService();
    });

    test('offline → cache boşsa boş liste döner', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          faultRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
          syncQueueServiceProvider.overrideWith(
            (ref) => FakeSyncQueueService(),
          ),
        ],
      );

      final result = await container.read(allFaultsProvider.future);
      expect(result, isEmpty);
      verifyNever(() => mockRepo.getAllFaults());
    });

    test('online başarı → repository çağrılır ve liste döner', () async {
      final faults = [
        TestFactories.createFaultReport(id: 'f1', description: 'Arıza 1'),
        TestFactories.createFaultReport(
          id: 'f2',
          description: 'Arıza 2',
          isResolved: true,
        ),
      ];
      when(() => mockRepo.getAllFaults()).thenAnswer((_) async => faults);

      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          faultRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
          syncQueueServiceProvider.overrideWith(
            (ref) => FakeSyncQueueService(),
          ),
        ],
      );

      final result = await container.read(allFaultsProvider.future);
      expect(result.length, 2);
      expect(result[0].description, 'Arıza 1');
      verify(() => mockRepo.getAllFaults()).called(1);
    });

    test('online hata + cache boşsa exception rethrow olur', () async {
      when(() => mockRepo.getAllFaults()).thenThrow(Exception('Ağ hatası'));

      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          faultRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
          syncQueueServiceProvider.overrideWith(
            (ref) => FakeSyncQueueService(),
          ),
        ],
      );

      await expectLater(
        container.read(allFaultsProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('activeFaultsProvider', () {
    late MockFaultRepository mockRepo;
    late FakeReadCacheService fakeCache;

    setUp(() {
      mockRepo = MockFaultRepository();
      fakeCache = FakeReadCacheService();
    });

    test('offline → cache boşsa boş liste döner', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          faultRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
          syncQueueServiceProvider.overrideWith(
            (ref) => FakeSyncQueueService(),
          ),
        ],
      );

      final result = await container.read(activeFaultsProvider.future);
      expect(result, isEmpty);
      verifyNever(() => mockRepo.getAllActiveFaults());
    });

    test('online başarı → sadece aktif arızalar döner', () async {
      final faults = [
        TestFactories.createFaultReport(id: 'f1', isResolved: false),
        TestFactories.createFaultReport(id: 'f2', isResolved: false),
      ];
      when(() => mockRepo.getAllActiveFaults()).thenAnswer((_) async => faults);

      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          faultRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
          syncQueueServiceProvider.overrideWith(
            (ref) => FakeSyncQueueService(),
          ),
        ],
      );

      final result = await container.read(activeFaultsProvider.future);
      expect(result.length, 2);
      expect(result.every((f) => !f.isResolved), isTrue);
      verify(() => mockRepo.getAllActiveFaults()).called(1);
    });
  });
}

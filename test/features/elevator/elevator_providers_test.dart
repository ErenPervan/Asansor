import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';

import '../../helpers/provider_test_utils.dart';
import '../../helpers/test_mocks.dart';
import '../../helpers/test_factories.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDateTime());
  });

  group('elevatorsProvider', () {
    late MockElevatorRepository mockRepo;
    late FakeReadCacheService fakeCache;

    setUp(() {
      mockRepo = MockElevatorRepository();
      fakeCache = FakeReadCacheService();
    });

    test('offline → cache boşsa boş liste döner', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          elevatorRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
        ],
      );

      final result = await container.read(elevatorsProvider.future);

      expect(result, isEmpty);
      verifyNever(() => mockRepo.getAllElevators());
    });

    test('online başarı → repository çağrılır ve liste döner', () async {
      final elevators = [
        TestFactories.createElevator(id: 'e1', buildingName: 'Bina A'),
        TestFactories.createElevator(id: 'e2', buildingName: 'Bina B'),
      ];
      when(() => mockRepo.getAllElevators()).thenAnswer((_) async => elevators);

      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          elevatorRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
        ],
      );

      final result = await container.read(elevatorsProvider.future);

      expect(result.length, 2);
      expect(result[0].buildingName, 'Bina A');
      verify(() => mockRepo.getAllElevators()).called(1);
    });

    test('online hata + cache boşsa exception rethrow olur', () async {
      when(
        () => mockRepo.getAllElevators(),
      ).thenThrow(Exception('Supabase bağlantı hatası'));

      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          elevatorRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
        ],
      );

      await expectLater(
        container.read(elevatorsProvider.future),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'elevatorByIdProvider offline → exception fırlatır (cache boş)',
      () async {
        final container = createContainer(
          overrides: [
            isOnlineProvider.overrideWithValue(false),
            elevatorRepositoryProvider.overrideWithValue(mockRepo),
            readCacheServiceProvider.overrideWithValue(fakeCache),
          ],
        );

        await expectLater(
          container.read(elevatorByIdProvider('e-unknown').future),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('elevatorByIdProvider online → repository çağrılır', () async {
      final elevator = TestFactories.createElevator(id: 'e1');
      when(
        () => mockRepo.getElevatorById('e1'),
      ).thenAnswer((_) async => elevator);

      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          elevatorRepositoryProvider.overrideWithValue(mockRepo),
          readCacheServiceProvider.overrideWithValue(fakeCache),
        ],
      );

      final result = await container.read(elevatorByIdProvider('e1').future);
      expect(result.id, 'e1');
      verify(() => mockRepo.getElevatorById('e1')).called(1);
    });
  });
}

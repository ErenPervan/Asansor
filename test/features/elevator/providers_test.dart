import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/fault/providers/fault_providers.dart';
import 'package:asansor/features/admin/repositories/schedule_repository.dart';
import '../../helpers/provider_test_utils.dart';
import '../../helpers/test_mocks.dart';

void main() {
  late MockFaultRepository mockFaultRepository;
  late MockScheduleRepository mockScheduleRepository;

  setUp(() {
    mockFaultRepository = MockFaultRepository();
    mockScheduleRepository = MockScheduleRepository();
  });

  group('latestFaultDateProvider', () {
    test('returns null when offline', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          faultRepositoryProvider.overrideWithValue(mockFaultRepository),
        ],
      );

      final result = await container.read(
        latestFaultDateProvider('elevator-1').future,
      );
      expect(result, isNull);
      verifyNever(() => mockFaultRepository.getLatestFaultDate(any()));
    });

    test('calls repository when online and returns date', () async {
      final expectedDate = DateTime.utc(2026, 6, 2, 12, 0);
      when(
        () => mockFaultRepository.getLatestFaultDate('elevator-1'),
      ).thenAnswer((_) async => expectedDate);

      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          faultRepositoryProvider.overrideWithValue(mockFaultRepository),
        ],
      );

      final result = await container.read(
        latestFaultDateProvider('elevator-1').future,
      );
      expect(result, expectedDate);
      verify(
        () => mockFaultRepository.getLatestFaultDate('elevator-1'),
      ).called(1);
    });
  });

  group('nextScheduledMaintenanceProvider', () {
    test('returns null when offline', () async {
      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          scheduleRepositoryProvider.overrideWithValue(mockScheduleRepository),
        ],
      );

      final result = await container.read(
        nextScheduledMaintenanceProvider('elevator-1').future,
      );
      expect(result, isNull);
      verifyNever(
        () => mockScheduleRepository.getNextScheduledMaintenanceDate(any()),
      );
    });

    test('calls repository when online and returns date', () async {
      final expectedDate = DateTime.utc(2026, 6, 15, 10, 0);
      when(
        () => mockScheduleRepository.getNextScheduledMaintenanceDate(
          'elevator-1',
        ),
      ).thenAnswer((_) async => expectedDate);

      final container = createContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          scheduleRepositoryProvider.overrideWithValue(mockScheduleRepository),
        ],
      );

      final result = await container.read(
        nextScheduledMaintenanceProvider('elevator-1').future,
      );
      expect(result, expectedDate);
      verify(
        () => mockScheduleRepository.getNextScheduledMaintenanceDate(
          'elevator-1',
        ),
      ).called(1);
    });
  });
}

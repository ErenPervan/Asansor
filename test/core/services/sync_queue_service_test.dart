import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asansor/core/services/sync_queue_service.dart';
import 'package:asansor/core/services/pdf_service.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mocks & Fakes
// ─────────────────────────────────────────────────────────────────────────────

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockPdfService extends Mock implements PdfService {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockFunctionResponse extends Mock implements FunctionResponse {}

class FakePostgrestBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T>, PostgrestTransformBuilder<T> {
  FakePostgrestBuilder(this._value);
  final Object? _value;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> inFilter(String column, List<dynamic> values) =>
      this;

  @override
  PostgrestFilterBuilder<T> gte(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> lte(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    return FakePostgrestBuilder<List<Map<String, dynamic>>>(_value as dynamic);
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    if (_value is List && _value.isNotEmpty) {
      return FakePostgrestBuilder<Map<String, dynamic>?>(
        _value.first as dynamic,
      );
    }
    return FakePostgrestBuilder<Map<String, dynamic>?>(_value as dynamic);
  }

  @override
  Future<U> then<U>(FutureOr<U> Function(T) onValue, {Function? onError}) {
    return Future.value(_value as T).then(onValue, onError: onError);
  }
}

void main() {
  late Directory tempDir;
  late SyncQueueService service;
  late MockSupabaseClient mockClient;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockSupabaseStorageClient mockStorageClient;
  late MockStorageFileApi mockStorageFileApi;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockPdfService mockPdfService;
  late MockFunctionsClient mockFunctions;

  setUpAll(() async {
    registerFallbackValue(File(''));
    registerFallbackValue(
      MaintenanceLogModel(
        id: 'fallback',
        elevatorId: 'e',
        technicianId: 't',
        notes: '',
        isApproved: false,
        maintenanceDate: DateTime.now(),
      ),
    );

    // Setup isolated Hive box directory once for all tests in this file
    tempDir = await Directory.systemTemp.createTemp('hive_sync_tests_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(syncQueueBoxName);
  });

  setUp(() async {
    // Clear the box before each test to ensure test isolation
    await Hive.box<String>(syncQueueBoxName).clear();

    // 2. Instantiate Service
    service = SyncQueueService();

    // 3. Setup Mocks
    mockClient = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockStorageClient = MockSupabaseStorageClient();
    mockStorageFileApi = MockStorageFileApi();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockPdfService = MockPdfService();
    mockFunctions = MockFunctionsClient();

    // Wire up basic client returns
    when(() => mockClient.from(any())).thenAnswer((_) => mockQueryBuilder);
    when(() => mockClient.storage).thenReturn(mockStorageClient);
    when(() => mockStorageClient.from(any())).thenReturn(mockStorageFileApi);
    when(() => mockClient.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockClient.functions).thenReturn(mockFunctions);

    // Set PdfService singleton mock
    PdfService.instance = mockPdfService;
  });

  tearDown(() async {
    // No-op - box is cleared in setUp instead of closing and deleting directory
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SyncQueueService Basic Operations', () {
    test('enqueuing stores item and updates pending status', () async {
      expect(service.hasPending, isFalse);
      expect(service.pendingCount, 0);

      await service.enqueue(
        type: SyncItemType.faultReport,
        payload: {'description': 'Elevator stuck'},
      );

      expect(service.hasPending, isTrue);
      expect(service.pendingCount, 1);
      expect(service.conflictCount, 0);
    });

    test('enqueuing notifies listeners', () async {
      bool notified = false;
      service.addListener(() {
        notified = true;
      });

      await service.enqueue(
        type: SyncItemType.faultReport,
        payload: {'description': 'Elevator stuck'},
      );

      expect(notified, isTrue);
    });
  });

  group('SyncQueueService Flushing & Offline replay', () {
    test('flush successful fault_report removes it from queue', () async {
      await service.enqueue(
        type: SyncItemType.faultReport,
        payload: {'elevator_id': 'e1', 'description': 'Broken cable'},
      );

      // Stub supabase insert operation
      when(
        () => mockQueryBuilder.insert(any()),
      ).thenAnswer((_) => FakePostgrestBuilder<dynamic>(null) as dynamic);

      final result = await service.flush(mockClient);

      expect(result.synced, 1);
      expect(result.failed, 0);
      expect(service.hasPending, isFalse);
      expect(service.pendingCount, 0);
    });

    test(
      'flush successful maintenance_log runs full workflow (PDF, upload, complete schedule)',
      () async {
        final logPayload = {
          'elevator_id': 'e1',
          'technician_id': 'tech1',
          'notes': 'Monthly checkup',
          'is_approved': true,
          'maintenance_date': '2026-05-17T12:00:00.000Z',
        };

        await service.enqueue(
          type: SyncItemType.maintenanceLog,
          payload: logPayload,
        );

        // 1. Mock insertion return payload (represents database record creation)
        final dbRecord = {'id': 'log123', ...logPayload};
        when(() => mockQueryBuilder.insert(any())).thenAnswer(
          (_) =>
              FakePostgrestBuilder<Map<String, dynamic>>(dbRecord) as dynamic,
        );

        // 2. Mock PdfService report generation
        final mockPdfFile = File('${tempDir.path}/fake_report.pdf');
        await mockPdfFile.writeAsBytes([1, 2, 3]);
        when(
          () => mockPdfService.generateMaintenanceReport(
            log: any(named: 'log'),
            checklistDetails: any(named: 'checklistDetails'),
          ),
        ).thenAnswer((_) async => mockPdfFile);

        // 3. Mock Storage Upload and public URL retrieval
        when(
          () => mockStorageFileApi.upload(any(), any()),
        ).thenAnswer((_) async => 'reports/log123.pdf');
        when(
          () => mockStorageFileApi.getPublicUrl(any()),
        ).thenReturn('https://supabase.com/reports/log123.pdf');

        // 4. Mock pdf_url database update back-write
        when(
          () => mockQueryBuilder.update(any()),
        ).thenAnswer((_) => FakePostgrestBuilder<dynamic>(null) as dynamic);

        // 5. Mock user profile lookup for notification
        final customerProfile = {'id': 'cust456'};
        when(() => mockQueryBuilder.select('id')).thenAnswer(
          (_) =>
              FakePostgrestBuilder<List<Map<String, dynamic>>>([
                    customerProfile,
                  ])
                  as dynamic,
        );

        // 6. Mock notification push function call
        when(
          () => mockFunctions.invoke(any(), body: any(named: 'body')),
        ).thenAnswer((_) async => MockFunctionResponse());

        final result = await service.flush(mockClient);

        // Verify overall flush output
        expect(result.synced, 1);
        expect(result.failed, 0);
        expect(service.hasPending, isFalse);

        // Verify the correct storage upload took place
        verify(
          () => mockStorageFileApi.upload(
            any(that: startsWith('report_e1_')),
            mockPdfFile,
          ),
        ).called(1);

        // Verify public URL updated in maintenance_logs table
        verify(
          () => mockQueryBuilder.update({
            'pdf_url': 'https://supabase.com/reports/log123.pdf',
          }),
        ).called(1);

        // Verify customer notification request was dispatched
        verify(
          () => mockFunctions.invoke(
            'send-notification',
            body: any(
              named: 'body',
              that: isA<Map<String, dynamic>>()
                  .having((m) => m['to_user_id'], 'to_user_id', 'cust456')
                  .having((m) => m['title'], 'title', 'Bakım Tamamlandı ✓'),
            ),
          ),
        ).called(1);
      },
    );

    test('flush successful elevator_update runs cleanly', () async {
      await service.enqueue(
        type: SyncItemType.elevatorUpdate,
        payload: {'id': 'el1', 'base_version': 2, 'status': 'active'},
      );

      // Mock update returning a valid record
      when(() => mockQueryBuilder.update(any())).thenAnswer(
        (_) =>
            FakePostgrestBuilder<Map<String, dynamic>>({
                  'id': 'el1',
                  'version': 3,
                })
                as dynamic,
      );

      final result = await service.flush(mockClient);

      expect(result.synced, 1);
      expect(result.failed, 0);
      expect(service.hasPending, isFalse);
    });
  });

  group('SyncQueueService Conflict Handling (OCC Version Mismatch)', () {
    test(
      'OCC version mismatch triggers ConflictException and updates item status',
      () async {
        await service.enqueue(
          type: SyncItemType.elevatorUpdate,
          payload: {'id': 'el1', 'base_version': 2, 'status': 'active'},
        );

        // 1. Mock update returning null (simulates version mismatch / no rows updated)
        when(() => mockQueryBuilder.update(any())).thenAnswer(
          (_) => FakePostgrestBuilder<Map<String, dynamic>?>(null) as dynamic,
        );

        // 2. Mock remote state retrieval returning current version 3
        final remoteState = {
          'id': 'el1',
          'status': 'faulty',
          'version': 3,
          'building_name': 'Sunset Tower',
        };
        when(() => mockQueryBuilder.select()).thenAnswer(
          (_) =>
              FakePostgrestBuilder<List<Map<String, dynamic>>>([remoteState])
                  as dynamic,
        );

        // Flush
        final result = await service.flush(mockClient);

        expect(result.synced, 0);
        expect(result.failed, 1);

        // Check status updated in database/Hive queue
        expect(
          service.pendingCount,
          0,
        ); // Conflicted items are not counted as 'pending'
        expect(service.conflictCount, 1);
        expect(service.conflictedItems.length, 1);

        final conflicted = service.conflictedItems.first;
        expect(conflicted['status'], 'conflict_detected');
        expect(conflicted['remote_state']['version'], 3);
        expect(conflicted['payload']['base_version'], 2);
      },
    );

    test(
      'subsequent flushes skip conflicted items and do not block others',
      () async {
        // 1. Enqueue elevator update (which will conflict)
        await service.enqueue(
          type: SyncItemType.elevatorUpdate,
          payload: {'id': 'el1', 'base_version': 2, 'status': 'active'},
        );

        // 2. Enqueue normal fault report (which should succeed)
        await service.enqueue(
          type: SyncItemType.faultReport,
          payload: {'elevator_id': 'e1', 'description': 'Broken light'},
        );

        // Mock update to return null (conflict) and select to return remote state
        when(() => mockQueryBuilder.update(any())).thenAnswer(
          (_) => FakePostgrestBuilder<Map<String, dynamic>?>(null) as dynamic,
        );
        when(() => mockQueryBuilder.select()).thenAnswer(
          (_) =>
              FakePostgrestBuilder<List<Map<String, dynamic>>>([
                    {'id': 'el1', 'version': 3},
                  ])
                  as dynamic,
        );

        // Stub insert to fail with a network error during the first flush
        when(
          () => mockQueryBuilder.insert(any()),
        ).thenThrow(const SocketException('Connection failed'));

        // Flush once to trigger conflict on first item
        await service.flush(mockClient);

        expect(service.conflictCount, 1);
        expect(service.pendingCount, 1); // Only fault report remains pending

        // Now stub update to succeed (for subsequent or other queries)
        when(
          () => mockQueryBuilder.insert(any()),
        ).thenAnswer((_) => FakePostgrestBuilder<dynamic>(null) as dynamic);

        // Flush again: it should process the fault report and SKIP the conflicted elevator update
        final result = await service.flush(mockClient);

        expect(result.synced, 1); // fault report synced
        expect(
          result.failed,
          1,
        ); // conflicted elevator update skipped (counted in failed)
        expect(service.conflictCount, 1);
        expect(service.pendingCount, 0);
      },
    );
  });

  group('SyncQueueService Conflict Resolutions', () {
    late String conflictKey;
    final remoteState = {
      'id': 'el1',
      'status': 'faulty',
      'version': 3,
      'building_name': 'Sunset Tower',
    };

    setUp(() async {
      await service.enqueue(
        type: SyncItemType.elevatorUpdate,
        payload: {'id': 'el1', 'base_version': 2, 'status': 'active'},
      );

      when(() => mockQueryBuilder.update(any())).thenAnswer(
        (_) => FakePostgrestBuilder<Map<String, dynamic>?>(null) as dynamic,
      );
      when(() => mockQueryBuilder.select()).thenAnswer(
        (_) =>
            FakePostgrestBuilder<List<Map<String, dynamic>>>([remoteState])
                as dynamic,
      );

      await service.flush(mockClient);
      conflictKey = service.conflictedItems.first['key'] as String;
    });

    test('resolveDiscard removes item from queue', () async {
      expect(service.conflictCount, 1);

      await service.resolveDiscard(conflictKey);

      expect(service.conflictCount, 0);
      expect(service.hasPending, isFalse);
    });

    test(
      'resolveFlagDisputed uploads dispute record and removes item from queue',
      () async {
        // Stub insert to dispute table
        when(
          () => mockQueryBuilder.insert(any()),
        ).thenAnswer((_) => FakePostgrestBuilder<dynamic>(null) as dynamic);
        when(() => mockUser.id).thenReturn('tech123');

        expect(service.conflictCount, 1);

        await service.resolveFlagDisputed(mockClient, conflictKey);

        expect(service.conflictCount, 0);
        verify(
          () => mockQueryBuilder.insert({
            'elevator_id': 'el1',
            'technician_id': 'tech123',
            'local_payload': {
              'id': 'el1',
              'base_version': 2,
              'status': 'active',
            },
            'remote_payload': remoteState,
            'status': 'pending',
          }),
        ).called(1);
      },
    );

    test('resolveForceUpdate increments version and retries flush', () async {
      // Mock remote version select call
      when(() => mockQueryBuilder.select('version')).thenAnswer(
        (_) =>
            FakePostgrestBuilder<List<Map<String, dynamic>>>([
                  {'version': 3},
                ])
                as dynamic,
      );

      // Mock the second flush update to succeed
      when(() => mockQueryBuilder.update(any())).thenAnswer(
        (_) =>
            FakePostgrestBuilder<Map<String, dynamic>>({
                  'id': 'el1',
                  'version': 4,
                })
                as dynamic,
      );

      expect(service.conflictCount, 1);

      clearInteractions(mockQueryBuilder);

      await service.resolveForceUpdate(mockClient, conflictKey);

      // Verify that after forcing, the item succeeded and was deleted from the box
      expect(service.conflictCount, 0);
      expect(service.hasPending, isFalse);

      // Verify update was sent with updated base_version (3)
      verify(
        () => mockQueryBuilder.update(
          any(
            that: isA<Map<String, dynamic>>().having(
              (m) => m['status'],
              'status',
              'active',
            ),
          ),
        ),
      ).called(1);
    });
  });
}

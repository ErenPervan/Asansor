import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:asansor/features/elevator/repositories/elevator_repository.dart';
import 'package:asansor/features/admin/repositories/schedule_repository.dart';
import 'package:asansor/core/services/pdf_service.dart';

// Supabase Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder {}

class MockPostgrestTransformBuilder<T> extends Mock
    implements PostgrestTransformBuilder<T> {}

// Hive Mocks
class MockHiveBox<T> extends Mock implements Box<T> {}

// Repository Mocks
class MockElevatorRepository extends Mock implements ElevatorRepository {}

class MockScheduleRepository extends Mock implements ScheduleRepository {}

// Service Mocks
class MockPdfService extends Mock implements PdfService {}

// Fake Classes for Fallbacks (if needed for mocktail)
class FakeDateTime extends Fake implements DateTime {}

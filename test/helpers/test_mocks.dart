import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import 'package:asansor/features/elevator/repositories/elevator_repository.dart';
import 'package:asansor/features/admin/repositories/schedule_repository.dart';
import 'package:asansor/features/admin/repositories/profile_repository.dart';
import 'package:asansor/features/maintenance/repositories/maintenance_repository.dart';
import 'package:asansor/features/fault/repositories/fault_repository.dart';
import 'package:asansor/features/auth/repositories/auth_repository.dart';
import 'package:asansor/core/services/pdf_service.dart';

// ── Supabase Mocks ────────────────────────────────────────────────────────────

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder {}

class MockPostgrestTransformBuilder<T> extends Mock
    implements PostgrestTransformBuilder<T> {}

// ── Hive Mocks ────────────────────────────────────────────────────────────────

class MockHiveBox<T> extends Mock implements Box<T> {}

// ── Repository Mocks (implement interfaces, not concrete classes) ─────────────

class MockElevatorRepository extends Mock implements IElevatorRepository {}

class MockScheduleRepository extends Mock implements IScheduleRepository {}

class MockMaintenanceRepository extends Mock
    implements IMaintenanceRepository {}

class MockFaultRepository extends Mock implements IFaultRepository {}

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockProfileRepository extends Mock implements IProfileRepository {}

// ── Service Mocks ─────────────────────────────────────────────────────────────

class MockPdfService extends Mock implements PdfService {}

// ── Fake Classes (mocktail fallbacks) ─────────────────────────────────────────

class FakeDateTime extends Fake implements DateTime {}

class MockStatefulNavigationShell extends Mock
    implements StatefulNavigationShell {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return super.toString();
  }
}

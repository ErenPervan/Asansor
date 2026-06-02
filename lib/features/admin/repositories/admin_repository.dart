import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/exceptions/app_exception.dart';

/// Aggregated statistics shown on the Admin Dashboard.
class AdminStats {
  const AdminStats({
    required this.totalElevators,
    required this.activeFaults,
    required this.completedThisMonth,
    required this.pendingThisMonth,
  });

  /// Total number of elevators registered in the system.
  final int totalElevators;

  /// Fault reports where `is_resolved = false`.
  final int activeFaults;

  /// Maintenance logs approved (`is_approved = true`) in the current month.
  final int completedThisMonth;

  /// Scheduled tasks with status `pending` in the current month.
  final int pendingThisMonth;
}

abstract interface class IAdminRepository {
  Future<AdminStats> getAdminStats();
}

/// Provides read-only aggregated queries for the Admin Dashboard.
class AdminRepository implements IAdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  /// Fetches all four KPI figures in a single logical operation.
  @override
  Future<AdminStats> getAdminStats() async {
    try {
      final now = DateTime.now().toUtc();
      final startOfMonth = DateTime.utc(now.year, now.month, 1);
      // First day of next month — used as an exclusive upper bound.
      final startOfNextMonth = now.month < 12
          ? DateTime.utc(now.year, now.month + 1, 1)
          : DateTime.utc(now.year + 1, 1, 1);

      // Run all queries concurrently to minimise latency.
      final results = await Future.wait([
        // 1 – Total elevators
        _client.from('elevators').select('id'),
        // 2 – Active (unresolved) fault reports
        _client.from('fault_reports').select('id').eq('is_resolved', false),
        // 3 – Approved maintenance logs this month
        _client
            .from('maintenance_logs')
            .select('id')
            .eq('is_approved', true)
            .gte('maintenance_date', startOfMonth.toIso8601String())
            .lt('maintenance_date', startOfNextMonth.toIso8601String()),
        // 4 – Pending maintenance schedules this month
        _client
            .from('maintenance_schedules')
            .select('id')
            .eq('status', 'pending')
            .gte('scheduled_date', startOfMonth.toIso8601String())
            .lt('scheduled_date', startOfNextMonth.toIso8601String()),
      ]);

      return AdminStats(
        totalElevators: (results[0] as List).length,
        activeFaults: (results[1] as List).length,
        completedThisMonth: (results[2] as List).length,
        pendingThisMonth: (results[3] as List).length,
      );
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getAdminStats');
    } catch (e) {
      throw mapUnknownException(e, 'getAdminStats');
    }
  }
}

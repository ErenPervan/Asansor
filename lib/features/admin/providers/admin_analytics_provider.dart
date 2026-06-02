import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/theme/app_colors.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class AdminAnalyticsState {
  const AdminAnalyticsState({
    required this.activeFaults,
    required this.completedMaintenancesThisMonth,
    required this.totalElevators,
    required this.pendingMaintenances,
    required this.monthlyFaults,
    required this.faultCategories,
  });

  final int activeFaults;
  final int completedMaintenancesThisMonth;
  final int totalElevators;
  final int pendingMaintenances;
  final List<MonthlyFaultData> monthlyFaults;
  final List<FaultCategoryData> faultCategories;
}

class MonthlyFaultData {
  const MonthlyFaultData({required this.month, required this.value});
  final String month;
  final double value;
}

class FaultCategoryData {
  const FaultCategoryData({
    required this.label,
    required this.percent,
    required this.color,
  });
  final String label;
  final double percent;
  final Color color;
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Fetches all KPI stats for the admin analytics / statistics dashboard.
///
/// All heavy classification logic (fault category grouping, monthly trend
/// bucketing) runs as PostgreSQL RPC functions on the server — no raw
/// description text or full-table payloads cross the wire.
///
/// RPC functions used:
///   • `get_fault_category_counts()` → [(category, count)]
///   • `get_monthly_fault_counts(months_back)` → [(year, month, count)]
final adminAnalyticsProvider =
    FutureProvider.autoDispose<AdminAnalyticsState>((ref) async {
  final supabase = ref.read(supabaseClientProvider);

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  // ── 1–4. KPI counts — single parallel round-trip ─────────────────────────
  final kpiResults = await Future.wait([
    supabase
        .from('fault_reports')
        .select('id')
        .eq('is_resolved', false)
        .count(CountOption.exact),
    supabase
        .from('maintenance_logs')
        .select('id')
        .gte('maintenance_date', startOfMonth.toIso8601String())
        .count(CountOption.exact),
    supabase.from('elevators').select('id').count(CountOption.exact),
    supabase
        .from('maintenance_schedules')
        .select('id')
        .eq('status', 'pending')
        .count(CountOption.exact),
  ]);

  final activeFaults = (kpiResults[0] as dynamic).count as int;
  final completedThisMonth = (kpiResults[1] as dynamic).count as int;
  final totalElevators = (kpiResults[2] as dynamic).count as int;
  final pendingMaintenances = (kpiResults[3] as dynamic).count as int;

  // ── 5. Monthly trend — server-side aggregation via RPC ────────────────────
  // Returns: [{year, month, count}]
  // Only aggregated numbers cross the wire — zero raw fault rows.
  final monthlyRows = await supabase.rpc(
    'get_monthly_fault_counts',
    params: {'months_back': 5},
  ) as List<dynamic>;

  // Build a lookup: 'YYYY-M' → count
  final Map<String, int> monthlyLookup = {
    for (final row in monthlyRows)
      '${row['year']}-${row['month']}': (row['count'] as int? ?? 0),
  };

  // Initialise ordered 6-month slots (current month inclusive).
  final monthFormat = DateFormat.MMM('tr_TR');
  final monthlyFaults = <MonthlyFaultData>[];
  for (int i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    final key = '${d.year}-${d.month}';
    monthlyFaults.add(MonthlyFaultData(
      month: monthFormat.format(d),
      value: (monthlyLookup[key] ?? 0).toDouble(),
    ));
  }

  // ── 6. Category distribution — server-side classification via RPC ─────────
  // Returns: [{category, count}]
  // Keyword matching and grouping execute entirely in PostgreSQL.
  // No description text, no raw rows, no client-side string.contains().
  final categoryRows = await supabase.rpc(
    'get_fault_category_counts',
  ) as List<dynamic>;

  final colors = [
    AppColors.blue,
    AppColors.violet,
    AppColors.successLight,
    AppColors.warningLight,
    AppColors.error,
    AppColors.outline,
  ];

  final int totalCount = categoryRows.fold<int>(
    0,
    (sum, row) => sum + (row['count'] as int? ?? 0),
  );

  final faultCategories = <FaultCategoryData>[];
  for (int i = 0; i < categoryRows.length; i++) {
    final row = categoryRows[i];
    final count = row['count'] as int? ?? 0;
    final percent = totalCount > 0 ? (count / totalCount) * 100.0 : 0.0;
    faultCategories.add(FaultCategoryData(
      label: row['category'] as String? ?? 'Diğer',
      percent: percent,
      color: colors[i % colors.length],
    ));
  }

  return AdminAnalyticsState(
    activeFaults: activeFaults,
    completedMaintenancesThisMonth: completedThisMonth,
    totalElevators: totalElevators,
    pendingMaintenances: pendingMaintenances,
    monthlyFaults: monthlyFaults,
    faultCategories: faultCategories.isEmpty
        ? const [
            FaultCategoryData(
              label: 'Veri Yok',
              percent: 100,
              color: AppColors.outline,
            ),
          ]
        : faultCategories,
  );
});

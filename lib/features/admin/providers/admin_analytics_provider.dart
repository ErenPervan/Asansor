import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
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

final adminAnalyticsProvider = FutureProvider.autoDispose<AdminAnalyticsState>((
  ref,
) async {
  final supabase = Supabase.instance.client;

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

  final results = await Future.wait([
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

  final activeFaultsRes = results[0];
  final completedThisMonthRes = results[1];
  final totalElevatorsRes = results[2];
  final pendingMaintenancesRes = results[3];

  // 5. 6-Month Fault Trend
  final recentFaults = await supabase
      .from('fault_reports')
      .select('reported_at')
      .gte('reported_at', sixMonthsAgo.toIso8601String());

  // Group by month
  final Map<String, int> monthlyCounts = {};

  // Initialize the last 6 months to ensure they all appear in the chart, in order.
  final monthFormat = DateFormat.MMM(
    'tr_TR',
  ); // Assuming Turkish locale as requested in mock
  final orderedMonths = <String>[];
  for (int i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    final monthStr = monthFormat.format(d);
    orderedMonths.add(monthStr);
    monthlyCounts[monthStr] = 0;
  }

  for (final fault in recentFaults) {
    if (fault['reported_at'] != null) {
      final date = DateTime.parse(fault['reported_at'] as String);
      final monthStr = monthFormat.format(date);
      if (monthlyCounts.containsKey(monthStr)) {
        monthlyCounts[monthStr] = monthlyCounts[monthStr]! + 1;
      }
    }
  }

  final monthlyFaults = orderedMonths
      .map(
        (m) => MonthlyFaultData(month: m, value: monthlyCounts[m]!.toDouble()),
      )
      .toList();

  // 6. Fault Category Distribution
  // Try fetching category. If it fails or is null, fallback to description keywords.
  final allFaultsForCategories = await supabase
      .from('fault_reports')
      .select('fault_type, description');

  final Map<String, int> categoryCounts = {};
  int totalCategories = 0;

  for (final fault in allFaultsForCategories) {
    String? cat = fault['fault_type'] as String?;

    // Fallback logic if category column is null
    if (cat == null || cat.trim().isEmpty) {
      final desc = (fault['description'] as String?)?.toLowerCase() ?? '';
      if (desc.contains('kapı')) {
        cat = 'Kapı Motoru';
      } else if (desc.contains('kart') ||
          desc.contains('elektronik') ||
          desc.contains('beyin')) {
        cat = 'Anakart / Elektronik';
      } else if (desc.contains('halat') || desc.contains('kablo')) {
        cat = 'Halat / Kablo';
      } else if (desc.contains('kabin') ||
          desc.contains('ışık') ||
          desc.contains('buton')) {
        cat = 'Kabin / Buton';
      } else {
        cat = 'Diğer';
      }
    }

    categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    totalCategories++;
  }

  // Define colors for top categories
  final colors = [
    AppColors.blue,
    AppColors.violet,
    AppColors.successLight,
    AppColors.warningLight,
    AppColors.error,
    AppColors.outline,
  ];

  final sortedCategories = categoryCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value)); // descending

  final faultCategories = <FaultCategoryData>[];
  for (int i = 0; i < sortedCategories.length; i++) {
    final entry = sortedCategories[i];
    final percent = totalCategories > 0
        ? (entry.value / totalCategories) * 100
        : 0.0;
    faultCategories.add(
      FaultCategoryData(
        label: entry.key,
        percent: percent,
        color: colors[i % colors.length],
      ),
    );
  }

  return AdminAnalyticsState(
    activeFaults: activeFaultsRes.count,
    completedMaintenancesThisMonth: completedThisMonthRes.count,
    totalElevators: totalElevatorsRes.count,
    pendingMaintenances: pendingMaintenancesRes.count,
    monthlyFaults: monthlyFaults,
    faultCategories: faultCategories.isEmpty
        ? [
            const FaultCategoryData(
              label: 'Veri Yok',
              percent: 100,
              color: AppColors.outline,
            ),
          ]
        : faultCategories,
  );
});

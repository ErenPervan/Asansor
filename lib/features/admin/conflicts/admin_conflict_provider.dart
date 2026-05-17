import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class ConflictReport {
  const ConflictReport({
    required this.id,
    required this.elevatorId,
    required this.technicianId,
    required this.localPayload,
    required this.remotePayload,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String elevatorId;
  final String technicianId;
  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> remotePayload;
  final String status;
  final DateTime createdAt;

  factory ConflictReport.fromJson(Map<String, dynamic> json) {
    return ConflictReport(
      id: json['id'] as String,
      elevatorId: json['elevator_id'] as String,
      technicianId: json['technician_id'] as String,
      localPayload: (json['local_payload'] as Map<String, dynamic>?) ?? {},
      remotePayload: (json['remote_payload'] as Map<String, dynamic>?) ?? {},
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class AdminConflictNotifier extends AsyncNotifier<List<ConflictReport>> {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<ConflictReport>> build() => _fetchPending();

  Future<List<ConflictReport>> _fetchPending() async {
    final rows = await _client
        .from('conflict_reports')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => ConflictReport.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ── Public actions ─────────────────────────────────────────────────────────

  /// Accepts the [chosenPayload] as the canonical version and marks the
  /// conflict report as resolved.
  ///
  /// If [chosenPayload] is the local payload, pass [ConflictReport.localPayload].
  /// If the remote state is preferred, pass [ConflictReport.remotePayload].
  Future<void> resolveConflict({
    required ConflictReport report,
    required Map<String, dynamic> chosenPayload,
  }) async {
    state = const AsyncLoading();

    try {
      // 1. Apply the chosen payload to the elevators table.
      //    Strip any OCC fields that belong to the sync queue, not the table.
      final sanitized = Map<String, dynamic>.from(chosenPayload)
        ..remove('id')
        ..remove('base_version');

      await _client
          .from('elevators')
          .update(sanitized)
          .eq('id', report.elevatorId);

      // 2. Mark the conflict report as resolved.
      await _client
          .from('conflict_reports')
          .update({
            'status': 'resolved',
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', report.id);

      // 3. Refresh the list.
      state = AsyncData(await _fetchPending());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Dismisses a conflict report without applying any changes (marks as
  /// 'dismissed' so it doesn't clutter the queue).
  Future<void> dismissConflict(String reportId) async {
    await _client
        .from('conflict_reports')
        .update({'status': 'dismissed'})
        .eq('id', reportId);

    state = AsyncData(await _fetchPending());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final adminConflictProvider =
    AsyncNotifierProvider<AdminConflictNotifier, List<ConflictReport>>(
      AdminConflictNotifier.new,
    );

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';
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
    this.buildingName,
    this.technicianName,
  });

  final String id;
  final String elevatorId;
  final String technicianId;
  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> remotePayload;
  final String status;
  final DateTime createdAt;
  final String? buildingName;
  final String? technicianName;

  factory ConflictReport.fromJson(Map<String, dynamic> json) {
    return ConflictReport(
      id: json['id'] as String,
      elevatorId: json['elevator_id'] as String,
      technicianId: json['technician_id'] as String,
      localPayload: (json['local_payload'] as Map<String, dynamic>?) ?? {},
      remotePayload: (json['remote_payload'] as Map<String, dynamic>?) ?? {},
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      buildingName: json['building_name'] as String?,
      technicianName: json['technician_name'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class AdminConflictNotifier extends AsyncNotifier<List<ConflictReport>> {
  @override
  Future<List<ConflictReport>> build() => _fetchPending();

  Future<List<ConflictReport>> _fetchPending() async {
    final client = ref.read(supabaseClientProvider);
    final rows = await client
        .from('conflict_reports')
        .select('*, elevators(building_name)')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    if (rows.isEmpty) return [];

    final List<String> technicianIds = (rows as List)
        .map((r) => r['technician_id'] as String)
        .toSet()
        .toList();

    final profilesResponse = await client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', technicianIds);

    final profileMap = {
      for (final p in profilesResponse)
        p['id'] as String: p['full_name'] as String?,
    };

    return (rows as List).map((r) {
      final map = Map<String, dynamic>.from(r as Map<String, dynamic>);
      final elevatorData = map['elevators'] as Map<String, dynamic>?;
      map['building_name'] = elevatorData?['building_name'];
      map['technician_name'] = profileMap[map['technician_id']];
      return ConflictReport.fromJson(map);
    }).toList();
  }

  // ── Public actions ─────────────────────────────────────────────────────────

  /// Apply the technician's offline changes (Force Update).
  /// This updates the target record with the local payload and increments its version.
  Future<void> resolveForceLocal(ConflictReport report) async {
    state = const AsyncLoading();
    final client = ref.read(supabaseClientProvider);

    try {
      final sanitized = Map<String, dynamic>.from(report.localPayload)
        ..remove('id')
        ..remove('base_version')
        ..remove('updated_at'); // will be set by DB or updated here

      final currentVersion = (report.remotePayload['version'] as int?) ?? 1;

      await client.rpc(
        'resolve_elevator_conflict',
        params: {
          'p_conflict_id': report.id,
          'p_elevator_id': report.elevatorId,
          'p_current_version': currentVersion,
          'p_payload': sanitized,
        },
      );

      state = AsyncData(await _fetchPending());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Discard the technician's offline changes (Keep Remote Data).
  /// Leaves the target record untouched, marks conflict as discarded.
  Future<void> resolveDiscardLocal(ConflictReport report) async {
    state = const AsyncLoading();
    final client = ref.read(supabaseClientProvider);

    try {
      await client
          .from('conflict_reports')
          .update({'status': 'resolved_discarded'})
          .eq('id', report.id);

      state = AsyncData(await _fetchPending());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final adminConflictProvider =
    AsyncNotifierProvider<AdminConflictNotifier, List<ConflictReport>>(
      AdminConflictNotifier.new,
    );

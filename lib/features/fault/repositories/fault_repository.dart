import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asansor/core/exceptions/app_exception.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';

abstract interface class IFaultRepository {
  Future<List<FaultReportModel>> getAllFaults();
  Future<DateTime?> getLatestFaultDate(String elevatorId);
  Future<FaultReportModel> reportFault({
    required String elevatorId,
    required String description,
    String? photoUrl,
  });
  Future<FaultReportModel> resolveFault(
    String faultId, {
    String? resolutionNotes,
  });
  Future<FaultReportModel> reopenFault(String faultId);
  Future<FaultReportModel> getFaultById(String id);
  Future<List<FaultReportModel>> getAllActiveFaults();
  Future<List<FaultReportModel>> getFaultsByElevatorId(String elevatorId);
}

class FaultRepository implements IFaultRepository {
  FaultRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'fault_reports';

  // ── Read ───────────────────────────────────────────────────────────────────

  @override
  Future<List<FaultReportModel>> getAllFaults() async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .order('reported_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (json) => FaultReportModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getAllFaults');
    } catch (e) {
      throw mapUnknownException(e, 'getAllFaults');
    }
  }

  /// Returns the [DateTime] of the most recent fault report for this elevator,
  /// or `null` when no fault reports exist yet.
  @override
  Future<DateTime?> getLatestFaultDate(String elevatorId) async {
    try {
      final response = await _client
          .from(_table)
          .select('reported_at')
          .eq('elevator_id', elevatorId)
          .order('reported_at', ascending: false)
          .limit(1);

      final rows = response as List<dynamic>;
      if (rows.isEmpty) return null;

      final raw = rows.first['reported_at'] as String?;
      if (raw == null) return null;
      return DateTime.parse(raw);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getLatestFaultDate($elevatorId)');
    } catch (e) {
      throw mapUnknownException(e, 'getLatestFaultDate($elevatorId)');
    }
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Inserts a new fault report and returns the saved record.
  @override
  Future<FaultReportModel> reportFault({
    required String elevatorId,
    required String description,
    String? photoUrl,
  }) async {
    try {
      final response = await _client
          .from(_table)
          .insert({
            'elevator_id': elevatorId,
            'description': description,
            'photo_url': photoUrl,
            'is_resolved': false,
            'reported_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();

      return FaultReportModel.fromJson(response);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'reportFault');
    } catch (e) {
      throw mapUnknownException(e, 'reportFault');
    }
  }

  /// Marks [faultId] as resolved. Optionally records [resolvedAt] if the
  /// `resolved_at` column exists (run the migration below first):
  ///
  /// ```sql
  /// alter table fault_reports
  ///   add column if not exists resolved_at timestamptz,
  ///   add column if not exists resolution_notes text;
  /// ```
  @override
  Future<FaultReportModel> resolveFault(
    String faultId, {
    String? resolutionNotes,
  }) async {
    try {
      final response = await _client
          .from(_table)
          .update({
            'is_resolved': true,
            'resolved_at': DateTime.now().toUtc().toIso8601String(),
            if (resolutionNotes != null && resolutionNotes.isNotEmpty)
              'resolution_notes': resolutionNotes,
          })
          .eq('id', faultId)
          .select()
          .single();

      return FaultReportModel.fromJson(response);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'resolveFault');
    } catch (e) {
      throw mapUnknownException(e, 'resolveFault');
    }
  }

  /// Re-opens a previously resolved fault.
  @override
  Future<FaultReportModel> reopenFault(String faultId) async {
    try {
      final response = await _client
          .from(_table)
          .update({'is_resolved': false, 'resolved_at': null})
          .eq('id', faultId)
          .select()
          .single();

      return FaultReportModel.fromJson(response);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'reopenFault');
    } catch (e) {
      throw mapUnknownException(e, 'reopenFault');
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Fetches a single fault report by [id].
  @override
  Future<FaultReportModel> getFaultById(String id) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .single();

      return FaultReportModel.fromJson(response);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getFaultById($id)');
    } catch (e) {
      throw mapUnknownException(e, 'getFaultById($id)');
    }
  }

  /// Returns all unresolved fault reports across every elevator, newest first.
  @override
  Future<List<FaultReportModel>> getAllActiveFaults() async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('is_resolved', false)
          .order('reported_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (json) => FaultReportModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getAllActiveFaults');
    } catch (e) {
      throw mapUnknownException(e, 'getAllActiveFaults');
    }
  }

  /// Returns all fault reports for a given [elevatorId], newest first.
  @override
  Future<List<FaultReportModel>> getFaultsByElevatorId(
    String elevatorId,
  ) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('elevator_id', elevatorId)
          .order('reported_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (json) => FaultReportModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getFaultsByElevatorId($elevatorId)');
    } catch (e) {
      throw mapUnknownException(e, 'getFaultsByElevatorId($elevatorId)');
    }
  }
}

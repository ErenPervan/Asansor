import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fault_report_model.dart';

class FaultRepository {
  FaultRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'fault_reports';

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<List<FaultReportModel>> getAllFaults() async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .order('reported_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => FaultReportModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Tüm arızalar yüklenemedi: $e');
    }
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Inserts a new fault report and returns the saved record.
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
    } on PostgrestException catch (e) {
      throw Exception('Failed to report fault: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error while reporting fault: $e');
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
    } on PostgrestException catch (e) {
      // Fall back gracefully if optional columns don't exist yet.
      if (e.message.contains('resolved_at') ||
          e.message.contains('resolution_notes') ||
          e.message.contains('column') ||
          e.message.contains('schema cache')) {
        final response = await _client
            .from(_table)
            .update({'is_resolved': true})
            .eq('id', faultId)
            .select()
            .single();
        return FaultReportModel.fromJson(response);
      }
      throw Exception('Arıza onarılamadı: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  /// Re-opens a previously resolved fault.
  Future<FaultReportModel> reopenFault(String faultId) async {
    try {
      final response = await _client
          .from(_table)
          .update({'is_resolved': false, 'resolved_at': null})
          .eq('id', faultId)
          .select()
          .single();

      return FaultReportModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.message.contains('resolved_at') ||
          e.message.contains('schema cache')) {
        final response = await _client
            .from(_table)
            .update({'is_resolved': false})
            .eq('id', faultId)
            .select()
            .single();
        return FaultReportModel.fromJson(response);
      }
      throw Exception('Arıza yeniden açılamadı: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Fetches a single fault report by [id].
  Future<FaultReportModel> getFaultById(String id) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .single();

      return FaultReportModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Arıza yüklenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  /// Returns all unresolved fault reports across every elevator, newest first.
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
    } on PostgrestException catch (e) {
      throw Exception('Failed to load active faults: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error while loading active faults: $e');
    }
  }

  /// Returns all fault reports for a given [elevatorId], newest first.
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
    } on PostgrestException catch (e) {
      throw Exception(
        'Failed to load faults for elevator ($elevatorId): ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Unexpected error while loading faults for elevator ($elevatorId): $e',
      );
    }
  }
}

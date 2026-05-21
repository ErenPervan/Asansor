import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/maintenance_log_model.dart';

class MaintenanceRepository {
  MaintenanceRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'maintenance_logs';

  /// Inserts a new maintenance log and returns the saved record.
  ///
  /// [elevatorId] — the elevator UUID this log belongs to.
  /// [technicianId] — UUID of the authenticated technician (auth.users).
  /// [notes] — free-text notes about the maintenance activity.
  /// [maintenanceDate] — date/time the maintenance was performed.
  /// [checklist] — the checked states of checklist items.
  Future<MaintenanceLogModel> addLog({
    required String elevatorId,
    required String technicianId,
    required String notes,
    required DateTime maintenanceDate,
    Map<String, dynamic>? checklist,
    List<String>? photos,
    String? signatureUrl,
    String? customerSignatureUrl,
  }) async {
    try {
      final response = await _client
          .from(_table)
          .insert({
            'elevator_id': elevatorId,
            'technician_id': technicianId,
            'notes': notes,
            'is_approved': false,
            'maintenance_date': maintenanceDate.toUtc().toIso8601String(),
            'checklist': ?checklist,
            if (photos != null && photos.isNotEmpty) 'photos': photos,
            'signature_url': ?signatureUrl,
            'customer_signature_url': ?customerSignatureUrl,
          })
          .select()
          .single();

      return MaintenanceLogModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to add maintenance log: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error while adding maintenance log: $e');
    }
  }

  /// Returns all pending (unapproved) maintenance logs across every elevator,
  /// ordered soonest-first so the most urgent work appears at the top.
  Future<List<MaintenanceLogModel>> getAllPendingLogs() async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('is_approved', false)
          .order('maintenance_date', ascending: true);

      return (response as List<dynamic>)
          .map(
            (json) =>
                MaintenanceLogModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load pending maintenance logs: ${e.message}');
    } catch (e) {
      throw Exception(
        'Unexpected error while loading pending maintenance logs: $e',
      );
    }
  }

  /// Returns the count of maintenance logs marked as approved today (UTC).
  Future<int> getCompletedTodayCount() async {
    try {
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from(_table)
          .select('id')
          .eq('is_approved', true)
          .gte('maintenance_date', startOfDay.toIso8601String())
          .lt('maintenance_date', endOfDay.toIso8601String());

      return (response as List<dynamic>).length;
    } on PostgrestException catch (e) {
      throw Exception('Failed to load completed count: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error while loading completed count: $e');
    }
  }

  /// Returns maintenance logs for a given [elevatorId] within the last
  /// [months] months, newest first. Used for transparency report generation.
  Future<List<MaintenanceLogModel>> getLogsForReport(
    String elevatorId, {
    int months = 6,
  }) async {
    try {
      final since = DateTime.now().toUtc().subtract(
        Duration(days: months * 30),
      );

      final response = await _client
          .from(_table)
          .select()
          .eq('elevator_id', elevatorId)
          .gte('maintenance_date', since.toIso8601String())
          .order('maintenance_date', ascending: false);

      return (response as List<dynamic>)
          .map(
            (json) =>
                MaintenanceLogModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(
        'Failed to load report logs for elevator ($elevatorId): ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Unexpected error while loading report logs for elevator ($elevatorId): $e',
      );
    }
  }

  /// Returns all maintenance logs for a given [elevatorId], newest first.
  ///
  /// Uses a relational select to join the `profiles` table and resolve each
  /// technician's full name from their UUID.  The alias syntax
  /// `profiles:technician_id(full_name)` tells PostgREST to follow the FK
  /// `maintenance_logs.technician_id → profiles.id` and embed the result as
  /// a nested `profiles` map on each row.
  Future<List<MaintenanceLogModel>> getLogsByElevatorId(
    String elevatorId,
  ) async {
    try {
      final response = await _client
          .from(_table)
          .select('*, profiles:technician_id(full_name)')
          .eq('elevator_id', elevatorId)
          .order('maintenance_date', ascending: false)
          .limit(20);

      return (response as List<dynamic>)
          .map(
            (json) =>
                MaintenanceLogModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(
        'Failed to load maintenance logs for elevator ($elevatorId): ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Unexpected error while loading logs for elevator ($elevatorId): $e',
      );
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/exceptions/app_exception.dart';
import '../models/maintenance_log_model.dart';

abstract interface class IMaintenanceRepository {
  Future<MaintenanceLogModel> addLog({
    required String elevatorId,
    required String technicianId,
    required String notes,
    required DateTime maintenanceDate,
    Map<String, dynamic>? checklist,
    List<String>? photos,
    String? signatureUrl,
    String? customerSignatureUrl,
  });
  Future<List<MaintenanceLogModel>> getAllPendingLogs();
  Future<int> getCompletedTodayCount();
  Future<List<MaintenanceLogModel>> getLogsForReport(
    String elevatorId, {
    int months = 6,
  });
  Future<List<MaintenanceLogModel>> getLogsByElevatorId(String elevatorId);
}

class MaintenanceRepository implements IMaintenanceRepository {
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
  @override
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
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'addLog');
    } catch (e) {
      throw mapUnknownException(e, 'addLog');
    }
  }

  /// Returns all pending (unapproved) maintenance logs across every elevator,
  /// ordered soonest-first so the most urgent work appears at the top.
  @override
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
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getAllPendingLogs');
    } catch (e) {
      throw mapUnknownException(e, 'getAllPendingLogs');
    }
  }

  /// Returns the count of maintenance logs marked as approved today (UTC).
  @override
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
          .lt('maintenance_date', endOfDay.toIso8601String())
          .count(CountOption.exact);

      return response.count;
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getCompletedTodayCount');
    } catch (e) {
      throw mapUnknownException(e, 'getCompletedTodayCount');
    }
  }

  /// Returns maintenance logs for a given [elevatorId] within the last
  /// [months] months, newest first. Used for transparency report generation.
  @override
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
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getLogsForReport($elevatorId)');
    } catch (e) {
      throw mapUnknownException(e, 'getLogsForReport($elevatorId)');
    }
  }

  /// Returns all maintenance logs for a given [elevatorId], newest first.
  ///
  /// Uses a relational select to join the `profiles` table and resolve each
  /// technician's full name from their UUID.  The alias syntax
  /// `profiles:technician_id(full_name)` tells PostgREST to follow the FK
  /// `maintenance_logs.technician_id → profiles.id` and embed the result as
  /// a nested `profiles` map on each row.
  @override
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
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getLogsByElevatorId($elevatorId)');
    } catch (e) {
      throw mapUnknownException(e, 'getLogsByElevatorId($elevatorId)');
    }
  }
}

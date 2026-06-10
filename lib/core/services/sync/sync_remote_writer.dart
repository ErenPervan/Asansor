import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asansor/core/exceptions/conflict_exception.dart';
import 'package:asansor/core/services/sync/sync_queue_storage.dart';
import 'package:asansor/core/services/sync/sync_media_uploader.dart';

const _dbWriteTimeout = Duration(seconds: 20);

class SyncRemoteWriter {
  final SupabaseClient _client;
  final SyncMediaUploader _mediaUploader;
  final SyncQueueStorage _storage;

  SyncRemoteWriter(this._client, this._mediaUploader, this._storage);

  Future<void> syncMaintenanceLog(
    Map<String, dynamic> payload,
    Map<String, dynamic> queueItem,
    String key,
  ) async {
    final elevatorId = payload['elevator_id'] as String?;
    final technicianId = payload['technician_id'] as String?;

    if (queueItem['status'] == statusSchedulePending) {
      await completeMatchingSchedule(
        elevatorId: elevatorId,
        technicianId: technicianId,
        maintenanceDate: payload['maintenance_date'] as String?,
      );
      return;
    }

    if (queueItem['status'] == statusPdfPending) {
      await _mediaUploader.generateUploadAndAttachPdf(
        _pdfPendingRemoteState(queueItem),
      );

      queueItem['status'] = statusSchedulePending;
      await _storage.put(key, jsonEncode(queueItem));

      await completeMatchingSchedule(
        elevatorId: elevatorId,
        technicianId: technicianId,
        maintenanceDate: payload['maintenance_date'] as String?,
      );
      return;
    }

    final row = Map<String, dynamic>.from(payload)
      ..remove('_complete_schedule');

    final rawPhotos = row['photos'];
    if (rawPhotos is List) {
      final photoPaths = rawPhotos.whereType<String>().toList();
      if (photoPaths.isNotEmpty) {
        final uploadedUrls = await _mediaUploader.resolveMaintenancePhotos(
          photoPaths,
          elevatorId: elevatorId,
          technicianId: technicianId,
        );
        if (uploadedUrls.isNotEmpty) {
          row['photos'] = uploadedUrls;
        } else {
          row.remove('photos');
        }
      } else {
        row.remove('photos');
      }
    } else {
      row.remove('photos');
    }

    final sigPath = row['signature_url'] as String?;
    if (sigPath != null) {
      final url = await _mediaUploader.resolveMaintenanceSignature(
        sigPath,
        elevatorId: elevatorId,
        technicianId: technicianId,
      );
      row['signature_url'] = url;
    }

    final custSigPath = row['customer_signature_url'] as String?;
    if (custSigPath != null) {
      final url = await _mediaUploader.resolveMaintenanceSignature(
        custSigPath,
        elevatorId: elevatorId,
        technicianId: technicianId,
      );
      row['customer_signature_url'] = url;
    }

    row['idempotency_key'] = queueItem['id'];

    final response = await _client
        .from('maintenance_logs')
        .insert(row)
        .select()
        .maybeSingle()
        .timeout(
          _dbWriteTimeout,
          onTimeout: () => throw TimeoutException(
            '[SyncRemoteWriter] Maintenance log insert timed out after ${_dbWriteTimeout.inSeconds}s',
          ),
        );
    if (response == null) {
      throw StateError('Maintenance log insert returned no row.');
    }
    queueItem['status'] = statusPdfPending;
    queueItem['payload'] = row;
    queueItem['remote_state'] = response;
    await _storage.put(key, jsonEncode(queueItem));

    await _mediaUploader.generateUploadAndAttachPdf(response);

    queueItem['status'] = statusSchedulePending;
    await _storage.put(key, jsonEncode(queueItem));

    await completeMatchingSchedule(
      elevatorId: elevatorId,
      technicianId: technicianId,
      maintenanceDate: payload['maintenance_date'] as String?,
    );
  }

  Map<String, dynamic> _pdfPendingRemoteState(Map<String, dynamic> queueItem) {
    final remoteState = queueItem['remote_state'];
    if (remoteState is Map<String, dynamic>) {
      return remoteState;
    }
    if (remoteState is Map) {
      return Map<String, dynamic>.from(remoteState);
    }

    throw StateError('Maintenance log is pdf_pending without remote_state.');
  }

  Future<void> completeMatchingSchedule({
    required String? elevatorId,
    required String? technicianId,
    String? maintenanceDate,
  }) async {
    if (elevatorId == null || technicianId == null) return;

    final targetDate = maintenanceDate != null
        ? DateTime.parse(maintenanceDate)
        : DateTime.now();
    final start = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    ).toIso8601String();
    final end = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      23,
      59,
      59,
    ).toIso8601String();

    await _client
        .from('maintenance_schedules')
        .update({'status': 'completed'})
        .eq('elevator_id', elevatorId)
        .eq('technician_id', technicianId)
        .inFilter('status', ['pending', 'in_progress'])
        .gte('scheduled_date', start)
        .lte('scheduled_date', end)
        .timeout(
          _dbWriteTimeout,
          onTimeout: () => throw TimeoutException(
            '[SyncRemoteWriter] Schedule completion update timed out after ${_dbWriteTimeout.inSeconds}s',
          ),
        );
  }

  Future<void> syncFaultReport(
    Map<String, dynamic> payload,
    String idempotencyKey,
  ) async {
    final row = Map<String, dynamic>.from(payload);
    row['idempotency_key'] = idempotencyKey;

    await _client
        .from('fault_reports')
        .insert(row)
        .timeout(
          _dbWriteTimeout,
          onTimeout: () => throw TimeoutException(
            '[SyncRemoteWriter] Fault report insert timed out after ${_dbWriteTimeout.inSeconds}s',
          ),
        );
  }

  Future<void> syncFaultResolve(
    Map<String, dynamic> payload,
  ) async {
    final faultId = payload['fault_id'] as String;
    final resolutionNotes = payload['resolution_notes'] as String?;
    final resolvedAt = payload['resolved_at'] as String;

    await _client
        .from('fault_reports')
        .update({
          'is_resolved': true,
          'resolved_at': resolvedAt,
          if (resolutionNotes != null && resolutionNotes.isNotEmpty)
            'resolution_notes': resolutionNotes,
        })
        .eq('id', faultId)
        .timeout(
          _dbWriteTimeout,
          onTimeout: () => throw TimeoutException(
            '[SyncRemoteWriter] Fault resolve update timed out after ${_dbWriteTimeout.inSeconds}s',
          ),
        );
  }

  Future<void> syncFaultReopen(
    Map<String, dynamic> payload,
  ) async {
    final faultId = payload['fault_id'] as String;

    await _client
        .from('fault_reports')
        .update({'is_resolved': false, 'resolved_at': null})
        .eq('id', faultId)
        .timeout(
          _dbWriteTimeout,
          onTimeout: () => throw TimeoutException(
            '[SyncRemoteWriter] Fault reopen update timed out after ${_dbWriteTimeout.inSeconds}s',
          ),
        );
  }

  Future<void> syncElevatorUpdate(
    Map<String, dynamic> payload,
  ) async {
    final id = payload['id'] as String;
    final baseVersion = payload['base_version'] as int;
    final changes = Map<String, dynamic>.from(payload)
      ..remove('id')
      ..remove('base_version');

    final response = await _client
        .from('elevators')
        .update(changes)
        .eq('id', id)
        .eq('version', baseVersion)
        .select()
        .maybeSingle()
        .timeout(
          _dbWriteTimeout,
          onTimeout: () => throw TimeoutException(
            '[SyncRemoteWriter] Elevator update timed out after ${_dbWriteTimeout.inSeconds}s for id: $id',
          ),
        );

    if (response == null) {
      final remote = await _client
          .from('elevators')
          .select()
          .eq('id', id)
          .maybeSingle()
          .timeout(
            _dbWriteTimeout,
            onTimeout: () => throw TimeoutException(
              '[SyncRemoteWriter] Elevator conflict-fetch timed out after ${_dbWriteTimeout.inSeconds}s for id: $id',
            ),
          );
      if (remote != null) {
        throw ConflictException(remoteState: remote);
      } else {
        throw Exception('Elevator not found for update.');
      }
    }
  }

  bool isTerminalError(Object error) {
    if (error is PostgrestException) {
      if (error.code != null) {
        final code = error.code!;
        // 22xxx (Data Exception), 23xxx (Integrity Constraint Violation), 42xxx (Syntax Error/Access Rule)
        if (code.startsWith('22') ||
            code.startsWith('23') ||
            code.startsWith('42')) {
          return true;
        }
      }
    } else if (error is StorageException) {
      if (error.statusCode != null) {
        final code = int.tryParse(error.statusCode!);
        if (code != null && code >= 400 && code < 500 && code != 429) {
          return true;
        }
      }
    }
    return false;
  }
}

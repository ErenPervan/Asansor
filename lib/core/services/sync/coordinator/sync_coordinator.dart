import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import 'package:asansor/core/exceptions/conflict_exception.dart';
import 'package:asansor/core/services/pdf_service.dart';
import 'package:asansor/core/services/sync/queue/sync_item.dart';
import 'package:asansor/core/services/sync/queue/sync_queue_repository.dart';
import 'package:asansor/core/services/sync/media/media_upload_service.dart';

const _pdfGenerationTimeout = Duration(seconds: 30);
const _uploadTimeout = Duration(seconds: 45);
const _dbWriteTimeout = Duration(seconds: 20);
const _maintenanceReportsBucket = 'maintenance-reports';

class SyncCoordinator {
  SyncCoordinator({
    required this.repository,
    required this.mediaUploadService,
    required this.notifyListeners,
  });

  final SyncQueueRepository repository;
  final MediaUploadService mediaUploadService;
  final VoidCallback notifyListeners;

  bool _isFlushing = false;

  Future<SyncResult> flush(SupabaseClient client) async {
    if (_isFlushing) return const SyncResult(synced: 0, failed: 0);
    _isFlushing = true;
    try {
      final keys = repository.keys;

      int synced = 0;
      int failed = 0;
      final Map<String, int> versionMap = {};

      for (final key in keys) {
        final raw = repository.get(key);
        if (raw == null) continue;

        try {
          final item = jsonDecode(raw) as Map<String, dynamic>;

          // Skip conflict_detected, dead_letter, or resolving items
          if (item['status'] == syncStatusConflictDetected ||
              item['status'] == syncStatusDeadLetter ||
              item['status'] == syncStatusResolving) {
            failed++;
            continue;
          }

          // Check if it's time to retry
          final nextRetryStr = item['next_retry_at'] as String?;
          if (nextRetryStr != null) {
            final nextRetry = DateTime.tryParse(nextRetryStr);
            if (nextRetry != null && DateTime.now().isBefore(nextRetry)) {
              continue; // skip this item, not time yet
            }
          }

          await _processWithVersionTracking(client, item, key, versionMap);
          await repository.delete(key);
          synced++;
        } on ConflictException catch (e) {
          final item = jsonDecode(raw) as Map<String, dynamic>;
          item['status'] = syncStatusConflictDetected;
          item['remote_state'] = e.remoteState;
          await repository.put(key, jsonEncode(item));
          notifyListeners();
          failed++;
        } catch (e, s) {
          debugPrint('[SyncCoordinator] Unexpected error in flush: $e\n$s');
          if (_isTerminalError(e)) {
            final item = jsonDecode(raw) as Map<String, dynamic>;
            item['status'] = syncStatusDeadLetter;
            item['error_details'] = e.toString();
            await repository.put(key, jsonEncode(item));
            notifyListeners();
          } else {
            // Transient error: increment attempt and calculate backoff
            final item = jsonDecode(raw) as Map<String, dynamic>;
            final attempt = (item['attempt_count'] as int? ?? 0) + 1;
            item['attempt_count'] = attempt;

            if (attempt >= syncMaxRetries) {
              item['status'] = syncStatusDeadLetter;
              item['error_details'] = 'Max retries exceeded: $e';
            } else {
              final delay = _calculateBackoff(attempt);
              item['next_retry_at'] = DateTime.now().add(delay).toIso8601String();
            }
            await repository.put(key, jsonEncode(item));
            notifyListeners();
          }
          failed++;
        }
      }

      // Always notify listeners so UI can reflect failures, conflicts, or successes
      notifyListeners();

      return SyncResult(synced: synced, failed: failed);
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _processWithVersionTracking(
    SupabaseClient client,
    Map<String, dynamic> item,
    String key,
    Map<String, int> versionMap,
  ) async {
    final type = item['type'] as String;
    final payload = Map<String, dynamic>.from(item['payload'] as Map);

    if (type == SyncItemType.elevatorUpdate) {
      final elevatorId = payload['id'] as String;
      if (versionMap.containsKey(elevatorId)) {
        payload['base_version'] = versionMap[elevatorId]!;
      }
      await _syncElevatorUpdate(client, payload);
      versionMap[elevatorId] = (payload['base_version'] as int) + 1;
      return;
    }

    await _process(client, item, key);
  }

  Duration _calculateBackoff(int attempt) {
    // attempt 1 => base * 1 = 30s
    // attempt 2 => base * 2 = 60s
    // attempt 3 => base * 4 = 120s
    final multiplier = 1 << (attempt - 1);
    final baseSeconds = syncBaseRetryDelaySeconds * multiplier;
    final jitterRange = (baseSeconds ~/ 4).clamp(1, 1000);
    final jitterSeconds = Random().nextInt(jitterRange);
    return Duration(seconds: baseSeconds + jitterSeconds);
  }

  Future<void> _process(
    SupabaseClient client,
    Map<String, dynamic> item,
    String key,
  ) async {
    final type = item['type'] as String;
    final payload = Map<String, dynamic>.from(item['payload'] as Map);

    switch (type) {
      case SyncItemType.maintenanceLog:
        await _syncMaintenanceLog(client, payload, item, key);
        break;
      case SyncItemType.faultReport:
        await _syncFaultReport(client, payload);
        break;
      case SyncItemType.elevatorUpdate:
        await _syncElevatorUpdate(client, payload);
        break;
      default:
        throw UnsupportedError('Unknown sync type: $type');
    }
  }

  Future<void> _syncMaintenanceLog(
    SupabaseClient client,
    Map<String, dynamic> payload,
    Map<String, dynamic> queueItem,
    String key,
  ) async {
    final elevatorId = payload['elevator_id'] as String?;
    final technicianId = payload['technician_id'] as String?;

    if (queueItem['status'] == syncStatusSchedulePending) {
      await _completeMatchingSchedule(
        client,
        elevatorId: elevatorId,
        technicianId: technicianId,
        maintenanceDate: payload['maintenance_date'] as String?,
      );
      return;
    }

    if (queueItem['status'] == syncStatusPdfPending) {
      await _generateUploadAndAttachPdf(
        client,
        _pdfPendingRemoteState(queueItem),
      );

      queueItem['status'] = syncStatusSchedulePending;
      await repository.put(key, jsonEncode(queueItem));

      await _completeMatchingSchedule(
        client,
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
        final uploadedUrls = await mediaUploadService.resolveMaintenancePhotos(
          client,
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
      final url = await mediaUploadService.resolveMaintenanceSignature(
        client,
        sigPath,
        elevatorId: elevatorId,
        technicianId: technicianId,
      );
      row['signature_url'] = url;
    }

    final custSigPath = row['customer_signature_url'] as String?;
    if (custSigPath != null) {
      final url = await mediaUploadService.resolveMaintenanceSignature(
        client,
        custSigPath,
        elevatorId: elevatorId,
        technicianId: technicianId,
      );
      row['customer_signature_url'] = url;
    }

    final response = await client
        .from('maintenance_logs')
        .upsert(row, onConflict: 'idempotency_key')
        .select()
        .maybeSingle()
        .timeout(
          _dbWriteTimeout,
          onTimeout: () => throw TimeoutException(
            '[SyncCoordinator] Maintenance log insert timed out',
          ),
        );
    if (response == null) {
      throw StateError('Maintenance log insert returned no row.');
    }
    queueItem['status'] = syncStatusPdfPending;
    queueItem['payload'] = row;
    queueItem['remote_state'] = response;
    await repository.put(key, jsonEncode(queueItem));

    await _generateUploadAndAttachPdf(client, response);

    queueItem['status'] = syncStatusSchedulePending;
    await repository.put(key, jsonEncode(queueItem));

    await _completeMatchingSchedule(
      client,
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

  Future<void> _generateUploadAndAttachPdf(
    SupabaseClient client,
    Map<String, dynamic> response,
  ) async {
    try {
      final logModel = MaintenanceLogModel.fromJson(response);
      final checklistDetails =
          logModel.checklist?.entries
              .map(
                (e) => ChecklistItem(label: e.key, isPassed: e.value == true),
              )
              .toList() ??
          <ChecklistItem>[];

      final pdfFile = await PdfService()
          .generateMaintenanceReport(
            log: logModel,
            checklistDetails: checklistDetails,
            mediaUrls: logModel.photos,
            signatureUrl: logModel.signatureUrl,
            customerSignatureUrl: logModel.customerSignatureUrl,
          )
          .timeout(
            _pdfGenerationTimeout,
            onTimeout: () => throw TimeoutException(
              '[SyncCoordinator] PDF generation timed out',
            ),
          );

      final fileName =
          'reports/${logModel.elevatorId}/report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await client.storage
          .from(_maintenanceReportsBucket)
          .upload(fileName, pdfFile)
          .timeout(
            _uploadTimeout,
            onTimeout: () => throw TimeoutException(
              '[SyncCoordinator] PDF upload timed out: $fileName',
            ),
          );

      final signedUrl = await client.storage
          .from(_maintenanceReportsBucket)
          .createSignedUrl(fileName, 60 * 60 * 24 * 365 * 10);
          
      await client
          .from('maintenance_logs')
          .update({'pdf_url': signedUrl})
          .eq('id', logModel.id)
          .timeout(
            _dbWriteTimeout,
            onTimeout: () => throw TimeoutException(
              '[SyncCoordinator] DB pdf_url update timed out for log ${logModel.id}',
            ),
          );
      debugPrint('[SyncCoordinator] PDF uploaded & linked: $signedUrl');

      try {
        final customerData = await client
            .from('profiles')
            .select('id')
            .eq('elevator_id', logModel.elevatorId)
            .eq('role', 'customer')
            .maybeSingle();

        if (customerData != null) {
          final customerId = customerData['id'] as String;
          await client.functions.invoke(
            'send-notification',
            body: {
              'to_user_id': customerId,
              'title': 'Bakım Tamamlandı ✓',
              'body':
                  'Asansörünüzün periyodik bakımı tamamlandı. Rapora göz atabilirsiniz.',
              'data': {'route': '/customer', 'pdf_url': signedUrl},
            },
          );
          debugPrint('[SyncCoordinator] Customer notification sent to: $customerId');
        } else {
          debugPrint(
            '[SyncCoordinator] No customer profile found for elevator ${logModel.elevatorId}. Skipping notification.',
          );
        }
      } catch (notifErr) {
        debugPrint(
          '[SyncCoordinator] Customer notification failed (non-fatal): $notifErr',
        );
      }
    } catch (e) {
      debugPrint('[SyncCoordinator] Failed to generate or upload PDF report: $e');
      throw Exception('PDF generation/upload failed');
    }
  }

  Future<void> _completeMatchingSchedule(
    SupabaseClient client, {
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

    await client
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
            '[SyncCoordinator] Schedule completion update timed out',
          ),
        );
  }

  Future<void> _syncFaultReport(
    SupabaseClient client,
    Map<String, dynamic> payload,
  ) async {
    await client
        .from('fault_reports')
        .upsert(payload, onConflict: 'idempotency_key')
        .timeout(
          _dbWriteTimeout,
          onTimeout: () => throw TimeoutException(
            '[SyncCoordinator] Fault report insert timed out',
          ),
        );
  }

  Future<void> _syncElevatorUpdate(
    SupabaseClient client,
    Map<String, dynamic> payload,
  ) async {
    final id = payload['id'] as String;
    final baseVersion = payload['base_version'] as int;
    final changes = Map<String, dynamic>.from(payload)
      ..remove('id')
      ..remove('base_version');

    final response = await client
        .from('elevators')
        .update(changes)
        .eq('id', id)
        .eq('version', baseVersion)
        .select()
        .maybeSingle()
        .timeout(
          _dbWriteTimeout,
          onTimeout: () => throw TimeoutException(
            '[SyncCoordinator] Elevator update timed out for id: $id',
          ),
        );

    if (response == null) {
      final remote = await client
          .from('elevators')
          .select()
          .eq('id', id)
          .maybeSingle()
          .timeout(
            _dbWriteTimeout,
            onTimeout: () => throw TimeoutException(
              '[SyncCoordinator] Elevator conflict-fetch timed out for id: $id',
            ),
          );
      if (remote != null) {
        throw ConflictException(remoteState: remote);
      } else {
        throw Exception('Elevator not found for update.');
      }
    }
  }

  bool _isTerminalError(Object error) {
    if (error is PostgrestException) {
      if (error.code != null) {
        final code = error.code!;
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

  // ── Conflict Resolution ───────────────────────────────────────────────────

  Future<void> resolveForceUpdate(SupabaseClient client, String key) async {
    final raw = repository.get(key);
    if (raw == null) return;

    final item = jsonDecode(raw) as Map<String, dynamic>;
    final payload = item['payload'] as Map<String, dynamic>;
    final id = payload['id'] as String;

    final remote = await client
        .from('elevators')
        .select('version')
        .eq('id', id)
        .maybeSingle();
    if (remote != null) {
      payload['base_version'] = remote['version'];
      item['status'] = syncStatusPending;
      item.remove('remote_state');
      await repository.put(key, jsonEncode(item));
      await flush(client);
    }
  }

  Future<void> resolveFlagDisputed(SupabaseClient client, String key) async {
    final raw = repository.get(key);
    if (raw == null) return;

    final item = jsonDecode(raw) as Map<String, dynamic>;
    final payload = item['payload'] as Map<String, dynamic>;
    final id = payload['id'] as String;
    final remoteState = item['remote_state'] as Map<String, dynamic>;

    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User not authenticated during conflict resolution.');
    }

    // 1. Mark local item as 'resolving' to prevent duplicate processing on crash
    item['status'] = syncStatusResolving;
    await repository.put(key, jsonEncode(item));

    // 2. Insert conflict report to remote DB
    await client.from('conflict_reports').insert({
      'elevator_id': id,
      'technician_id': userId,
      'local_payload': payload,
      'remote_payload': remoteState,
      'status': syncStatusPending,
    });

    // 3. If successful, delete the local item
    await repository.delete(key);
    notifyListeners();
  }

  Future<void> resolveDiscard(String key) async {
    await repository.delete(key);
    notifyListeners();
  }
}

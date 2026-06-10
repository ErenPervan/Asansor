import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';
import 'package:asansor/core/services/pdf_service.dart';
import 'package:asansor/core/services/notification_service.dart';

const _maintenancePhotosBucket = 'maintenance-photos';
const _maintenanceReportsBucket = 'maintenance-reports';
const _uploadTimeout = Duration(seconds: 45);
const _pdfGenerationTimeout = Duration(seconds: 30);
const _dbWriteTimeout = Duration(seconds: 20);

class SyncMediaUploader {
  final SupabaseClient _client;

  SyncMediaUploader(this._client);

  bool _isRemoteUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  String _safeExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return 'jpg';
    }
    final extension = path.substring(dotIndex + 1).toLowerCase();
    if (extension.length > 5) {
      return 'jpg';
    }
    return extension;
  }

  Future<List<String>> resolveMaintenancePhotos(
    List<String> photoPaths, {
    required String? elevatorId,
    required String? technicianId,
  }) async {
    final storage = _client.storage.from(_maintenancePhotosBucket);
    final uploadedUrls = <String>[];
    var index = 0;

    for (final path in photoPaths) {
      if (_isRemoteUrl(path)) {
        uploadedUrls.add(path);
        continue;
      }

      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[SyncMediaUploader] Missing photo at $path; skipping.');
        continue;
      }

      final extension = _safeExtension(path);
      final fileName =
          'maintenance_logs/${elevatorId ?? 'unknown'}/${technicianId ?? 'unknown'}_${DateTime.now().millisecondsSinceEpoch}_$index.$extension';
      index++;

      await storage
          .upload(fileName, file)
          .timeout(
            _uploadTimeout,
            onTimeout: () => throw TimeoutException(
              '[SyncMediaUploader] Photo upload timed out after ${_uploadTimeout.inSeconds}s: $fileName',
            ),
          );
      uploadedUrls.add(storage.getPublicUrl(fileName));
    }

    return uploadedUrls;
  }

  Future<String> resolveMaintenanceSignature(
    String path, {
    required String? elevatorId,
    required String? technicianId,
  }) async {
    if (_isRemoteUrl(path)) return path;

    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Maintenance signature is missing', path);
    }

    final urls = await resolveMaintenancePhotos(
      [path],
      elevatorId: elevatorId,
      technicianId: technicianId,
    );
    if (urls.isEmpty) {
      throw FileSystemException(
        'Maintenance signature could not be uploaded',
        path,
      );
    }

    return urls.first;
  }

  Future<void> generateUploadAndAttachPdf(Map<String, dynamic> response) async {
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
              '[SyncMediaUploader] PDF generation timed out after ${_pdfGenerationTimeout.inSeconds}s for log ${logModel.id}',
            ),
          );

      final fileName =
          'reports/${logModel.elevatorId}/${DateTime.now().millisecondsSinceEpoch}.pdf';
      await _client.storage
          .from(_maintenanceReportsBucket)
          .upload(fileName, pdfFile)
          .timeout(
            _uploadTimeout,
            onTimeout: () => throw TimeoutException(
              '[SyncMediaUploader] PDF upload timed out after ${_uploadTimeout.inSeconds}s: $fileName',
            ),
          );

      final signedUrl = await _client.storage
          .from(_maintenanceReportsBucket)
          .createSignedUrl(fileName, 3600 * 24 * 7); // 7 days

      await _client
          .from('maintenance_logs')
          .update({'pdf_url': signedUrl})
          .eq('id', logModel.id)
          .timeout(
            _dbWriteTimeout,
            onTimeout: () => throw TimeoutException(
              '[SyncMediaUploader] DB pdf_url update timed out after ${_dbWriteTimeout.inSeconds}s for log ${logModel.id}',
            ),
          );
      debugPrint(
        '[SyncMediaUploader] PDF uploaded & linked signed url for: $fileName',
      );

      try {
        final customerData = await _client
            .from('profiles')
            .select('id')
            .eq('elevator_id', logModel.elevatorId)
            .eq('role', 'customer')
            .maybeSingle();

        if (customerData != null) {
          final customerId = customerData['id'] as String;
          await _client.functions.invoke(
            'send-notification',
            body: {
              'to_user_id': customerId,
              'title': 'Bakım Tamamlandı ✓',
              'body':
                  'Asansörünüzün periyodik bakımı tamamlandı. Rapora göz atabilirsiniz.',
              'data': {'route': '/customer/dashboard', 'pdf_url': fileName},
            },
          );
          debugPrint(
            '[SyncMediaUploader] Customer notification sent to: $customerId',
          );
        } else {
          debugPrint(
            '[SyncMediaUploader] No customer profile found for elevator ${logModel.elevatorId}. Skipping notification.',
          );
        }
      } catch (notifErr) {
        debugPrint(
          '[SyncMediaUploader] Customer notification failed (non-fatal): $notifErr',
        );
      }

      try {
        await NotificationService.instance.notifyAllAdmins(
          client: _client,
          title: 'Bakım Tamamlandı',
          body: 'Bir teknisyen bakım görevini tamamladı.',
          data: {
            'type': 'task_completed',
            'route': '/admin/master-calendar',
            'elevator_id': logModel.elevatorId,
          },
        );
      } catch (e) {
        debugPrint(
          '[SyncMediaUploader] Admin notification failed (non-fatal): $e',
        );
      }
    } catch (e) {
      debugPrint(
        '[SyncMediaUploader] Failed to generate or upload PDF report: $e',
      );
      throw Exception('PDF generation/upload failed');
    }
  }
}

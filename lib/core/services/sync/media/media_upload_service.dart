import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _uploadTimeout = Duration(seconds: 45);
const _maintenancePhotosBucket = 'maintenance-photos';

class MediaUploadService {
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
    SupabaseClient client,
    List<String> photoPaths, {
    required String? elevatorId,
    required String? technicianId,
  }) async {
    final storage = client.storage.from(_maintenancePhotosBucket);
    final uploadedUrls = <String>[];
    var index = 0;

    for (final path in photoPaths) {
      if (_isRemoteUrl(path)) {
        uploadedUrls.add(path);
        continue;
      }

      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[MediaUploadService] Missing photo at $path; skipping.');
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
              '[MediaUploadService] Photo upload timed out after ${_uploadTimeout.inSeconds}s: $fileName',
            ),
          );
      final signedUrl = await storage.createSignedUrl(fileName, 60 * 60 * 24 * 365 * 10);
      uploadedUrls.add(signedUrl);
    }

    return uploadedUrls;
  }

  Future<String> resolveMaintenanceSignature(
    SupabaseClient client,
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
      client,
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
}

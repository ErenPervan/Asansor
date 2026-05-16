import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  StorageService(this._client);

  final SupabaseClient _client;
  static const _bucket = 'fault-images';

  /// Uploads an image file to Supabase Storage and returns its public URL.
  Future<String> uploadImage(File file, String folderPath, {String bucketName = _bucket}) async {
    try {
      final ext = file.path.split('.').last;
      final fileName = '${const Uuid().v4()}.$ext';
      final fullPath = '$folderPath/$fileName';

      await _client.storage.from(bucketName).upload(fullPath, file);
      return getPublicUrl(fullPath, bucketName: bucketName);
    } on StorageException catch (e) {
      throw Exception('Storage hatası: ${e.message}');
    } catch (e) {
      throw Exception('Görsel yüklenemedi: $e');
    }
  }

  /// Uploads raw bytes to Supabase Storage and returns its public URL.
  Future<String> uploadBytes(List<int> bytes, String fullPath, {String bucketName = _bucket, String? contentType}) async {
    try {
      await _client.storage.from(bucketName).uploadBinary(
        fullPath, 
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(contentType: contentType),
      );
      return getPublicUrl(fullPath, bucketName: bucketName);
    } on StorageException catch (e) {
      throw Exception('Storage hatası (Bytes): ${e.message}');
    } catch (e) {
      throw Exception('Veri yüklenemedi: $e');
    }
  }

  /// Returns the public URL for a given path.
  String getPublicUrl(String path, {String bucketName = _bucket}) {
    return _client.storage.from(bucketName).getPublicUrl(path);
  }

  /// Deletes an image from the storage bucket.
  Future<void> deleteImage(String path, {String bucketName = _bucket}) async {
    try {
      await _client.storage.from(bucketName).remove([path]);
    } on StorageException catch (e) {
      throw Exception('Storage hatası (Silme): ${e.message}');
    } catch (e) {
      throw Exception('Görsel silinemedi: $e');
    }
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(Supabase.instance.client);
});

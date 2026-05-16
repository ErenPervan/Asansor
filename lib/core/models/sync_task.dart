import 'package:hive/hive.dart';

class SyncTask {
  static const int typeId = 41;

  const SyncTask({
    required this.id,
    required this.endpoint,
    required this.payload,
    required this.localMediaPaths,
    required this.uploadedMediaUrls,
    required this.isMediaFullyUploaded,
    required this.createdAt,
  });

  final String id;
  final String endpoint;
  final Map<String, dynamic> payload;
  final List<String> localMediaPaths;
  final List<String> uploadedMediaUrls;
  final bool isMediaFullyUploaded;
  final DateTime createdAt;

  SyncTask copyWith({
    String? id,
    String? endpoint,
    Map<String, dynamic>? payload,
    List<String>? localMediaPaths,
    List<String>? uploadedMediaUrls,
    bool? isMediaFullyUploaded,
    DateTime? createdAt,
  }) {
    return SyncTask(
      id: id ?? this.id,
      endpoint: endpoint ?? this.endpoint,
      payload: payload ?? this.payload,
      localMediaPaths: localMediaPaths ?? this.localMediaPaths,
      uploadedMediaUrls: uploadedMediaUrls ?? this.uploadedMediaUrls,
      isMediaFullyUploaded: isMediaFullyUploaded ?? this.isMediaFullyUploaded,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'endpoint': endpoint,
      'payload': payload,
      'local_media_paths': localMediaPaths,
      'uploaded_media_urls': uploadedMediaUrls,
      'is_media_fully_uploaded': isMediaFullyUploaded,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SyncTask.fromJson(Map<String, dynamic> json) {
    return SyncTask(
      id: json['id'] as String,
      endpoint: json['endpoint'] as String,
      payload: json['payload'] != null
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
      localMediaPaths: json['local_media_paths'] != null
          ? List<String>.from(json['local_media_paths'] as List)
          : <String>[],
      uploadedMediaUrls: json['uploaded_media_urls'] != null
          ? List<String>.from(json['uploaded_media_urls'] as List)
          : <String>[],
      isMediaFullyUploaded:
          (json['is_media_fully_uploaded'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SyncTaskAdapter extends TypeAdapter<SyncTask> {
  @override
  int get typeId => SyncTask.typeId;


  @override
  SyncTask read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return SyncTask(
      id: fields[0] as String,
      endpoint: fields[1] as String,
      payload: fields[2] != null
          ? Map<String, dynamic>.from(fields[2] as Map)
          : <String, dynamic>{},
      localMediaPaths: fields[3] != null
          ? List<String>.from(fields[3] as List)
          : <String>[],
      uploadedMediaUrls: fields[4] != null
          ? List<String>.from(fields[4] as List)
          : <String>[],
      isMediaFullyUploaded: (fields[5] as bool?) ?? false,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SyncTask obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.endpoint)
      ..writeByte(2)
      ..write(obj.payload)
      ..writeByte(3)
      ..write(obj.localMediaPaths)
      ..writeByte(4)
      ..write(obj.uploadedMediaUrls)
      ..writeByte(5)
      ..write(obj.isMediaFullyUploaded)
      ..writeByte(6)
      ..write(obj.createdAt);
  }
}

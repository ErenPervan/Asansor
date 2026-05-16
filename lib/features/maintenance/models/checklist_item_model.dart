class ChecklistItemModel {
  final String id;
  final String label;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  ChecklistItemModel({
    required this.id,
    required this.label,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  factory ChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return ChecklistItemModel(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

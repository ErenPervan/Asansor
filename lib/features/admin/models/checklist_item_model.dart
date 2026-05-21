class ChecklistItemModel {
  const ChecklistItemModel({
    required this.id,
    required this.label,
    required this.description,
    required this.isActive,
  });

  final String id;
  final String label;
  final String description;
  final bool isActive;

  factory ChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return ChecklistItemModel(
      id: json['id'] as String,
      label: json['label'] as String,
      description: (json['description'] as String?) ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'description': description,
    'is_active': isActive,
  };

  ChecklistItemModel copyWith({
    String? id,
    String? label,
    String? description,
    bool? isActive,
  }) {
    return ChecklistItemModel(
      id: id ?? this.id,
      label: label ?? this.label,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }
}

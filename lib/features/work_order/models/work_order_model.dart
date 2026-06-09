// ignore_for_file: constant_identifier_names

enum WorkOrderPriority { low, medium, high, critical }
enum WorkOrderStatus { open, in_progress, pending_approval, resolved, closed, cancelled }
enum WorkOrderSource { manual, fault_report, schedule, sla_trigger }

class WorkOrderModel {
  final String id;
  final String? elevatorId;
  final String? createdBy;
  final String? assignedTo;
  final String title;
  final String? description;
  final WorkOrderPriority priority;
  final WorkOrderStatus status;
  final WorkOrderSource source;
  final String? sourceId;
  final DateTime? dueDate;
  final DateTime? resolvedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkOrderModel({
    required this.id,
    this.elevatorId,
    this.createdBy,
    this.assignedTo,
    required this.title,
    this.description,
    this.priority = WorkOrderPriority.medium,
    this.status = WorkOrderStatus.open,
    this.source = WorkOrderSource.manual,
    this.sourceId,
    this.dueDate,
    this.resolvedAt,
    this.approvedBy,
    this.approvedAt,
    this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkOrderModel.fromJson(Map<String, dynamic> json) {
    return WorkOrderModel(
      id: json['id'] as String,
      elevatorId: json['elevator_id'] as String?,
      createdBy: json['created_by'] as String?,
      assignedTo: json['assigned_to'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: _parsePriority(json['priority'] as String?),
      status: _parseStatus(json['status'] as String?),
      source: _parseSource(json['source'] as String?),
      sourceId: json['source_id'] as String?,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at'] as String) : null,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
      idempotencyKey: json['idempotency_key'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (elevatorId != null) 'elevator_id': elevatorId,
      if (createdBy != null) 'created_by': createdBy,
      if (assignedTo != null) 'assigned_to': assignedTo,
      'title': title,
      if (description != null) 'description': description,
      'priority': priority.name,
      'status': status.name,
      'source': source.name,
      if (sourceId != null) 'source_id': sourceId,
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
      if (approvedBy != null) 'approved_by': approvedBy,
      if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static WorkOrderPriority _parsePriority(String? p) {
    switch (p) {
      case 'low': return WorkOrderPriority.low;
      case 'high': return WorkOrderPriority.high;
      case 'critical': return WorkOrderPriority.critical;
      default: return WorkOrderPriority.medium;
    }
  }

  static WorkOrderStatus _parseStatus(String? s) {
    switch (s) {
      case 'in_progress': return WorkOrderStatus.in_progress;
      case 'pending_approval': return WorkOrderStatus.pending_approval;
      case 'resolved': return WorkOrderStatus.resolved;
      case 'closed': return WorkOrderStatus.closed;
      case 'cancelled': return WorkOrderStatus.cancelled;
      default: return WorkOrderStatus.open;
    }
  }

  static WorkOrderSource _parseSource(String? s) {
    switch (s) {
      case 'fault_report': return WorkOrderSource.fault_report;
      case 'schedule': return WorkOrderSource.schedule;
      case 'sla_trigger': return WorkOrderSource.sla_trigger;
      default: return WorkOrderSource.manual;
    }
  }

  WorkOrderModel copyWith({
    String? assignedTo,
    String? title,
    String? description,
    WorkOrderPriority? priority,
    WorkOrderStatus? status,
    DateTime? dueDate,
    DateTime? resolvedAt,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? updatedAt,
  }) {
    return WorkOrderModel(
      id: id,
      elevatorId: elevatorId,
      createdBy: createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      source: source,
      sourceId: sourceId,
      dueDate: dueDate ?? this.dueDate,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asansor/features/work_order/models/work_order_model.dart';
import 'package:asansor/core/services/sync_queue_service.dart';
import 'package:uuid/uuid.dart';

class WorkOrderRepository {
  final SupabaseClient _client;
  final SyncQueueService _syncQueue;

  WorkOrderRepository(this._client, this._syncQueue);

  Future<List<WorkOrderModel>> getMyWorkOrders() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final response = await _client
        .from('work_orders')
        .select()
        .eq('assigned_to', uid)
        .order('created_at', ascending: false)
        .limit(1000);

    return (response as List).map((json) => WorkOrderModel.fromJson(json)).toList();
  }

  Future<List<WorkOrderModel>> getAllWorkOrders() async {
    final response = await _client
        .from('work_orders')
        .select()
        .order('created_at', ascending: false)
        .limit(1000);

    return (response as List).map((json) => WorkOrderModel.fromJson(json)).toList();
  }

  Future<WorkOrderModel> getWorkOrderById(String id) async {
    final response = await _client
        .from('work_orders')
        .select()
        .eq('id', id)
        .single();
    
    return WorkOrderModel.fromJson(response);
  }

  Future<void> createWorkOrder(WorkOrderModel order) async {
    // Write directly to local queue for offline-first behavior
    await _syncQueue.enqueue(
      type: SyncItemType.genericUpsert,
      payload: {
        'table': 'work_orders',
        'data': order.toJson(),
      },
    );
    
    // Try to flush immediately
    _syncQueue.flush(_client).ignore();
  }

  Future<void> updateStatus(String id, WorkOrderStatus newStatus, {String? note}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    
    // We enqueue an RPC or an update. For simplicity, just an update to work_orders
    // and an insert to work_order_history.
    
    // 1. Update work order status
    await _syncQueue.enqueue(
      type: SyncItemType.genericUpsert,
      payload: {
        'table': 'work_orders',
        'data': {
          'id': id,
          'status': newStatus.name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          if (newStatus == WorkOrderStatus.resolved || newStatus == WorkOrderStatus.closed)
            'resolved_at': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );

    // 2. Insert history record
    final historyId = const Uuid().v4();
    await _syncQueue.enqueue(
      type: SyncItemType.genericUpsert,
      payload: {
        'table': 'work_order_history',
        'data': {
          'id': historyId,
          'work_order_id': id,
          'changed_by': uid,
          'new_status': newStatus.name,
          'note': note,
          'changed_at': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );

    _syncQueue.flush(_client).ignore();
  }
}

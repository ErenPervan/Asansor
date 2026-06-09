import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/features/work_order/models/work_order_model.dart';
import 'package:asansor/features/work_order/repositories/work_order_repository.dart';

final workOrderRepositoryProvider = Provider<WorkOrderRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final syncQueue = ref.watch(syncQueueServiceProvider);
  return WorkOrderRepository(client, syncQueue);
});

final myWorkOrdersProvider = FutureProvider.autoDispose<List<WorkOrderModel>>((ref) async {
  final repo = ref.watch(workOrderRepositoryProvider);
  return repo.getMyWorkOrders();
});

final allWorkOrdersProvider = FutureProvider.autoDispose<List<WorkOrderModel>>((ref) async {
  final repo = ref.watch(workOrderRepositoryProvider);
  return repo.getAllWorkOrders();
});

final workOrderDetailProvider = FutureProvider.family.autoDispose<WorkOrderModel, String>((ref, id) async {
  final repo = ref.watch(workOrderRepositoryProvider);
  return repo.getWorkOrderById(id);
});

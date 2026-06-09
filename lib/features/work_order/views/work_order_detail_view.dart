import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/features/work_order/models/work_order_model.dart';
import 'package:asansor/features/work_order/providers/work_order_providers.dart';

class WorkOrderDetailView extends ConsumerWidget {
  final String orderId;
  const WorkOrderDetailView({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOrder = ref.watch(workOrderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('İş Emri Detayı')),
      body: asyncOrder.when(
        data: (order) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('Durum: ${order.status.name}'),
                Text('Öncelik: ${order.priority.name}'),
                const SizedBox(height: 16),
                if (order.description != null) ...[
                  Text('Açıklama:', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(order.description!),
                  const SizedBox(height: 24),
                ],

                // Parts Used Section (Placeholder for UI integration)
                Text('Kullanılan Malzemeler:', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Henüz malzeme eklenmemiş.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (order.status == WorkOrderStatus.in_progress)
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Open Add Part Dialog
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Malzeme Ekle'),
                  ),
                const SizedBox(height: 24),
                
                // Status Actions
                _buildActionButtons(context, ref, order),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, WorkOrderModel order) {
    final repo = ref.read(workOrderRepositoryProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (order.status == WorkOrderStatus.open)
          FilledButton(
            onPressed: () {
              repo.updateStatus(order.id, WorkOrderStatus.in_progress, note: 'İşleme alındı');
              ref.invalidate(workOrderDetailProvider(order.id));
            },
            child: const Text('İşleme Al'),
          ),
        if (order.status == WorkOrderStatus.in_progress)
          FilledButton(
            onPressed: () {
              repo.updateStatus(order.id, WorkOrderStatus.resolved, note: 'Çözüldü olarak işaretlendi');
              ref.invalidate(workOrderDetailProvider(order.id));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Çözüldü İşaretle'),
          ),
      ],
    );
  }
}

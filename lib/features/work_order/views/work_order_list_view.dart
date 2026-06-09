import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asansor/features/work_order/models/work_order_model.dart';
import 'package:asansor/features/work_order/providers/work_order_providers.dart';
import 'package:asansor/core/theme/app_colors.dart';

import 'package:asansor/features/admin/providers/profile_providers.dart';

class WorkOrderListView extends ConsumerWidget {
  const WorkOrderListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final role = profile?.role ?? 'customer';
    final workOrdersAsync = role == 'admin' 
      ? ref.watch(allWorkOrdersProvider) 
      : ref.watch(myWorkOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('İş Emirleri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allWorkOrdersProvider);
              ref.invalidate(myWorkOrdersProvider);
            },
          ),
        ],
      ),
      body: workOrdersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('Aktif iş emri bulunmuyor.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allWorkOrdersProvider);
              ref.invalidate(myWorkOrdersProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _WorkOrderCard(order: order);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Hata: $e')),
      ),
      floatingActionButton: role == 'admin' ? FloatingActionButton(
        onPressed: () {
          // TODO: Open Create Work Order Sheet
        },
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  final WorkOrderModel order;
  const _WorkOrderCard({required this.order});

  Color _getPriorityColor(WorkOrderPriority priority) {
    switch (priority) {
      case WorkOrderPriority.low: return Colors.grey;
      case WorkOrderPriority.medium: return Colors.blue;
      case WorkOrderPriority.high: return Colors.orange;
      case WorkOrderPriority.critical: return Colors.red;
    }
  }

  String _getStatusText(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.open: return 'Açık';
      case WorkOrderStatus.in_progress: return 'İşlemde';
      case WorkOrderStatus.pending_approval: return 'Onay Bekliyor';
      case WorkOrderStatus.resolved: return 'Çözüldü';
      case WorkOrderStatus.closed: return 'Kapalı';
      case WorkOrderStatus.cancelled: return 'İptal';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/work-orders/${order.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (order.status == WorkOrderStatus.open && _isSlaAtRisk(order))
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('SLA RİSKİ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(order.priority).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _getPriorityColor(order.priority)),
                    ),
                    child: Text(
                      order.priority.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getPriorityColor(order.priority),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8),
              if (order.description != null) ...[
                Text(
                  order.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(
                    label: Text(_getStatusText(order.status)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: order.status == WorkOrderStatus.resolved || order.status == WorkOrderStatus.closed 
                      ? Colors.green.withValues(alpha: 0.1) : AppThemeColors.of(context).surfaceContainer,
                  ),
                  Text(
                    '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                    style: Theme.of(context).textTheme.labelSmall,
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  bool _isSlaAtRisk(WorkOrderModel order) {
    final now = DateTime.now();
    final elapsedMinutes = now.difference(order.createdAt).inMinutes;
    switch (order.priority) {
      case WorkOrderPriority.critical: return elapsedMinutes > 60;
      case WorkOrderPriority.high: return elapsedMinutes > 120;
      case WorkOrderPriority.medium: return elapsedMinutes > 240;
      case WorkOrderPriority.low: return elapsedMinutes > 1440;
    }
  }
}

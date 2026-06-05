import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/core/services/sync_queue_service.dart';

class ConflictResolutionView extends ConsumerWidget {
  const ConflictResolutionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncQueue = ref.watch(syncQueueServiceProvider);
    final conflicts = syncQueue.conflictedItems;

    return Scaffold(
      appBar: AppBar(title: const Text('Sync Conflicts')),
      body: conflicts.isEmpty
          ? const Center(child: Text('No conflicts to resolve.'))
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: conflicts.length,
              itemBuilder: (context, index) {
                final item = conflicts[index];
                return _ConflictCard(item: item, syncQueue: syncQueue);
              },
            ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.item, required this.syncQueue});

  final Map<String, dynamic> item;
  final SyncQueueService syncQueue;

  @override
  Widget build(BuildContext context) {
    final key = item['key'] as String;
    final payload = item['payload'] as Map<String, dynamic>;
    final remoteState = item['remote_state'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conflict on Elevator ID: ${payload['id']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Changes',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        const JsonEncoder.withIndent('  ').convert(payload),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remote State',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        const JsonEncoder.withIndent('  ').convert(remoteState),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      await syncQueue.resolveForceUpdate(
                        Supabase.instance.client,
                        key,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Update forced successfully.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to force update: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Force Update'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await syncQueue.resolveFlagDisputed(
                        Supabase.instance.client,
                        key,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Conflict reported for review.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to report conflict: $e'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.flag),
                  label: const Text('Report to Admin'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await syncQueue.resolveDiscard(key);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Local changes discarded.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Discard'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

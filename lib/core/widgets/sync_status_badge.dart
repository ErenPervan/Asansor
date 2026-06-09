import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';

class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(syncHealthProvider);

    IconData icon;
    Color color;
    String tooltip;

    switch (health) {
      case SyncHealth.ok:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        tooltip = 'Tümü senkronize';
        break;
      case SyncHealth.pending:
        icon = Icons.sync;
        color = Colors.blue;
        tooltip = 'Eşitleniyor...';
        break;
      case SyncHealth.conflict:
        icon = Icons.warning_amber_rounded;
        color = Colors.orange;
        tooltip = 'Çakışma tespit edildi';
        break;
      case SyncHealth.deadLetter:
        icon = Icons.error_outline;
        color = Colors.red;
        tooltip = 'Eşitleme hatası';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color, size: 20),
    );
  }
}

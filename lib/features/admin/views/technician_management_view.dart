import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/providers/admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asansor/features/admin/widgets/technician_management/technician_management_shared.dart';
import 'package:asansor/features/admin/widgets/technician_management/technician_workspace.dart';

class TechnicianManagementView extends ConsumerWidget {
  const TechnicianManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final dataAsync = ref.watch(technicianManagementProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Icon(Icons.elevator_rounded, color: colors.primary),
            const SizedBox(width: 10),
            Text(
              'Asansör',
              style: textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              'Operasyon Yönetimi',
              style: textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(technicianManagementProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dataAsync.when(
        loading: () => const LoadingState(),
        error: (e, st) => ErrorBody(
          error: e,
          onRetry: () => ref.invalidate(technicianManagementProvider),
        ),
        data: (stats) => TechnicianWorkspace(
          stats: stats,
          onRefresh: () => ref.invalidate(technicianManagementProvider),
        ),
      ),
    );
  }
}

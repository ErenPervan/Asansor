import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';

class TopAppBar extends StatelessWidget {
  const TopAppBar({
    super.key,
    required this.userEmail,
    required this.pendingSyncCount,
    required this.conflictSyncCount,
    required this.failedSyncCount,
    required this.isOnline,
    required this.canAccessAdmin,
    required this.activeFaultCount,
    required this.onSignOut,
  });

  final String userEmail;
  final int pendingSyncCount;
  final int conflictSyncCount;
  final int failedSyncCount;
  final bool isOnline;
  final bool canAccessAdmin;
  final int activeFaultCount;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final displayName = userEmail.isNotEmpty
        ? userEmail.split('@').first
        : 'Teknisyen';

    final (statusText, statusIcon, statusColor) = !isOnline
        ? ('Cevrimdisi', Icons.cloud_off_rounded, colors.warning)
        : failedSyncCount > 0
        ? ('Hata', Icons.error_outline_rounded, colors.error)
        : conflictSyncCount > 0
        ? ('Cakisma', Icons.warning_amber_rounded, colors.warning)
        : pendingSyncCount > 0
        ? ('Senkronize', Icons.sync_rounded, colors.primary)
        : ('Senkronize', Icons.cloud_done_rounded, colors.primary);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.06),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.domain_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Asansor',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.primaryDark,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (canAccessAdmin)
                    _TopIconButton(
                      icon: Icons.admin_panel_settings_outlined,
                      tooltip: 'Admin paneli',
                      onTap: () => context.push('/admin/dashboard'),
                    ),
                  if (canAccessAdmin) const SizedBox(width: AppSpacing.sm),
                  SyncStatusButton(
                    pendingCount: pendingSyncCount,
                    conflictCount: conflictSyncCount,
                    failedCount: failedSyncCount,
                    isOnline: isOnline,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _TopIconButton(
                    icon: Icons.logout_outlined,
                    tooltip: 'Cikis yap',
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cikis Yap'),
                          content: const Text(
                            'Oturumu kapatmak istediginize emin misiniz?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Iptal'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error,
                              ),
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Cikis Yap'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        onSignOut();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operasyon Ozeti',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canAccessAdmin
                          ? 'Gunluk operasyon'
                          : 'Merhaba, $displayName',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (canAccessAdmin && activeFaultCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$activeFaultCount acik ariza takipte',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surfaceContainerLow,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: colors.primary, size: 20),
          ),
        ),
      ),
    );
  }
}

class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({
    super.key,
    required this.pendingCount,
    required this.conflictCount,
    required this.failedCount,
    required this.isOnline,
  });

  final int pendingCount;
  final int conflictCount;
  final int failedCount;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final hasPending = pendingCount > 0;
    final hasFailed = failedCount > 0;
    final hasConflict = conflictCount > 0;

    final IconData icon;
    final Color color;
    final String tooltip;

    if (!isOnline) {
      icon = Icons.cloud_off_outlined;
      color = colors.warning;
      tooltip = 'Cevrimdisi';
    } else if (hasFailed) {
      icon = Icons.error_outline_rounded;
      color = colors.error;
      tooltip = '$failedCount kayit basarisiz oldu';
    } else if (hasConflict) {
      icon = Icons.warning_amber_rounded;
      color = colors.warning;
      tooltip = '$conflictCount cakisma var';
    } else if (hasPending) {
      icon = Icons.cloud_upload_outlined;
      color = colors.warning;
      tooltip = '$pendingCount kayit senkronize bekliyor';
    } else {
      icon = Icons.cloud_done_outlined;
      color = colors.primary;
      tooltip = 'Tum veriler senkronize';
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surfaceContainerLow,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _showSyncSheet(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 20),
                if (hasPending)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: hasFailed ? colors.error : colors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        hasFailed
                            ? '$failedCount'
                            : hasConflict
                            ? '$conflictCount'
                            : '$pendingCount',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSyncSheet(BuildContext context, WidgetRef ref) {
    final queue = ref.read(syncQueueServiceProvider);
    final count = queue.pendingCount;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SyncSheet(
        pendingCount: count,
        isOnline: isOnline,
        onSync: () {
          Navigator.pop(context);
          queue.flush(ref.read(supabaseClientProvider)).then((result) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.hasFailures
                        ? '${result.synced} senkronize edildi, ${result.failed} basarisiz'
                        : '${result.synced} kayit senkronize edildi',
                  ),
                  backgroundColor: result.hasFailures
                      ? AppThemeColors.of(context).error
                      : AppThemeColors.of(context).success,
                ),
              );
            }
          });
        },
      ),
    );
  }
}

class SyncSheet extends StatelessWidget {
  const SyncSheet({
    super.key,
    required this.pendingCount,
    required this.isOnline,
    required this.onSync,
  });

  final int pendingCount;
  final bool isOnline;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final hasPending = pendingCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: hasPending
                  ? colors.warningContainer
                  : colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasPending
                  ? Icons.cloud_upload_outlined
                  : Icons.cloud_done_outlined,
              size: 28,
              color: hasPending ? colors.warning : colors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasPending ? 'Bekleyen senkronizasyon' : 'Tum veriler senkronize',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasPending
                ? '$pendingCount kayit cevrimdisi olarak saklandi.'
                : 'Bakim ve ariza kayitlari sunucu ile guncel.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hasPending && isOnline)
            FilledButton.icon(
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Simdi senkronize et'),
              onPressed: onSync,
            ),
          if (!isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.warningContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: colors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Internet baglantisi yok. Baglanti kuruldugunda otomatik senkronize edilecek.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.warning,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

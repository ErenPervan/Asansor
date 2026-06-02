import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/connectivity_providers.dart';

class TopAppBar extends StatelessWidget {
  const TopAppBar({
    super.key,
    required this.userEmail,
    required this.pendingSyncCount,
    required this.isOnline,
    required this.isAdmin,
    required this.activeFaultCount,
    required this.onSignOut,
  });

  final String userEmail;
  final int pendingSyncCount;
  final bool isOnline;
  final bool isAdmin;
  final int activeFaultCount;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final displayName = userEmail.isNotEmpty
        ? userEmail.split('@').first
        : 'Teknisyen';

    final String statusText;
    if (!isOnline) {
      statusText = 'DURUM: ÇEVRİMDIŞI';
    } else if (pendingSyncCount > 0) {
      statusText = 'DURUM: SENKRONİZE EDİLİYOR';
    } else {
      statusText = 'DURUM: AKTİF';
    }

    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.12),
                width: 2,
              ),
            ),
            child: Icon(Icons.person_outline, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          // Status + greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.outline,
                        letterSpacing: 1.1,
                      ),
                ),
                Text(
                  isAdmin
                      ? 'Merhaba Admin — $activeFaultCount açık arıza'
                      : 'Merhaba, $displayName',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                        letterSpacing: -0.3,
                      ),
                ),
              ],
            ),
          ),
          // Admin panel shortcut
          if (isAdmin)
            Material(
              color: colors.surfaceContainerLowest,
              shape: const CircleBorder(),
              elevation: 1,
              shadowColor: colors.outline.withValues(alpha: 0.12),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push('/admin/dashboard'),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          if (isAdmin) const SizedBox(width: 8),
          // Cloud sync status indicator
          SyncStatusButton(pendingCount: pendingSyncCount, isOnline: isOnline),
          const SizedBox(width: 8),
          // Sign-out button
          Material(
            color: colors.surfaceContainerLowest,
            shape: const CircleBorder(),
            elevation: 1,
            shadowColor: colors.outline.withValues(alpha: 0.12),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Çıkış Yap'),
                    content: const Text(
                      'Oturumu kapatmak istediğinize emin misiniz?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('İptal'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Çıkış Yap'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  onSignOut();
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.logout_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Sync status button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Small button shown in the top bar to indicate cloud sync state.
///
/// - Green cloud-done icon  â†’ all data is synced.
/// - Amber cloud-upload icon with a count badge â†’ items are queued offline.
/// - No network icon (red)  â†’ device is currently offline.
class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({
    super.key,
    required this.pendingCount,
    required this.isOnline,
  });

  final int pendingCount;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPending = pendingCount > 0;

    final IconData icon;
    final Color color;
    final String tooltip;

    if (!isOnline) {
      icon = Icons.cloud_off_outlined;
      color = AppThemeColors.of(context).warning;
      tooltip = 'Çevrimdışı';
    } else if (hasPending) {
      icon = Icons.cloud_upload_outlined;
      color = AppThemeColors.of(context).warning;
      tooltip = '$pendingCount öğe senkronize bekleniyor';
    } else {
      icon = Icons.cloud_done_outlined;
      color = AppThemeColors.of(context).success;
      tooltip = 'Tüm veriler senkronize';
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppThemeColors.of(context).surfaceContainerLowest,
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: AppThemeColors.of(context).outline.withValues(alpha: 0.12),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _showSyncSheet(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    );
                  },
                  child: Icon(
                    icon,
                    key: ValueKey(icon),
                    color: color,
                    size: 20,
                  ),
                ),
                if (hasPending)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppThemeColors.of(context).warning,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                        textAlign: TextAlign.center,
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

  static supabase_flutter.SupabaseClient get _supabaseClient =>
      supabase_flutter.Supabase.instance.client;

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
          queue.flush(_supabaseClient).then((result) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.hasFailures
                        ? '${result.synced} senkronize edildi, '
                              '${result.failed} başarısız'
                        : '${result.synced} öğe başarıyla senkronize edildi',
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

/// Bottom sheet showing the current sync status with a manual sync button.
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
    final hasPending = pendingCount > 0;
    final colors = AppThemeColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: hasPending
                  ? colors.warningContainer
                  : colors.successContainer,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.elasticOut,
                  ),
                  child: child,
                );
              },
              child: Icon(
                hasPending
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_done_outlined,
                key: ValueKey(hasPending),
                size: 28,
                color: hasPending
                    ? colors.warning
                    : colors.success,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            hasPending ? 'Bekleyen Senkronizasyon' : 'Tüm Veriler Senkronize',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            hasPending
                ? '$pendingCount kayıt çevrimdışı olarak saklandı.'
                      '${isOnline ? ' Şimdi senkronize edebilirsiniz.' : ' İnternet bağlantısı gerekli.'}'
                : 'Tüm bakım ve arıza kayıtları Supabase ile senkronize.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
          ),

          const SizedBox(height: 24),

          if (hasPending && isOnline)
            FilledButton.icon(
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Şimdi Senkronize Et'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.success,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: onSync,
            ),

          if (!isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.warningContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    color: colors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'İnternet bağlantısı yok. Bağlantı kurulduğunda otomatik senkronize edilecek.',
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

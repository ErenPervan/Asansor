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
    required this.onSignOut,
  });

  final String userEmail;
  final int pendingSyncCount;
  final bool isOnline;
  final bool isAdmin;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final displayName = userEmail.isNotEmpty
        ? userEmail.split('@').first
        : 'Teknisyen';

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
            child: Icon(
              Icons.person_outline,
              color: colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Status + greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DURUM: AKTÄ°F',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.outline,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Merhaba, $displayName',
                  style: TextStyle(
                    fontSize: 17,
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
              shadowColor: Colors.black12,
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
          SyncStatusButton(
            pendingCount: pendingSyncCount,
            isOnline: isOnline,
          ),
          const SizedBox(width: 8),
          // Sign-out button
          Material(
            color: colors.surfaceContainerLowest,
            shape: const CircleBorder(),
            elevation: 1,
            shadowColor: Colors.black12,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSignOut,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.logout_outlined, color: AppColors.primary, size: 20),
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
      color = AppColors.primary;
      tooltip = 'Ã‡evrimdÄ±ÅŸÄ±';
    } else if (hasPending) {
      icon = Icons.cloud_upload_outlined;
      color = const Color(0xFFD97706); // amber-600
      tooltip = '$pendingCount Ã¶ÄŸe senkronize bekleniyor';
    } else {
      icon = Icons.cloud_done_outlined;
      color = const Color(0xFF16A34A); // green-600
      tooltip = 'TÃ¼m veriler senkronize';
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppThemeColors.of(context).surfaceContainerLowest,
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: Colors.black12,
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
                  child: Icon(icon, key: ValueKey(icon), color: color, size: 20),
                ),
                if (hasPending)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                          minWidth: 14, minHeight: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD97706),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
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
                  content: Text(result.hasFailures
                      ? '${result.synced} senkronize edildi, '
                          '${result.failed} baÅŸarÄ±sÄ±z'
                      : '${result.synced} Ã¶ÄŸe baÅŸarÄ±yla senkronize edildi'),
                  backgroundColor: result.hasFailures
                      ? AppColors.primary
                      : const Color(0xFF16A34A),
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
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFDCFCE7),
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
                    ? const Color(0xFFD97706)
                    : const Color(0xFF16A34A),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            hasPending ? 'Bekleyen Senkronizasyon' : 'TÃ¼m Veriler Senkronize',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasPending
                ? '$pendingCount kayÄ±t Ã§evrimdÄ±ÅŸÄ± olarak saklandÄ±.'
                    '${isOnline ? ' Åimdi senkronize edebilirsiniz.' : ' Ä°nternet baÄŸlantÄ±sÄ± gerekli.'}'
                : 'TÃ¼m bakÄ±m ve arÄ±za kayÄ±tlarÄ± Supabase ile senkronize.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          if (hasPending && isOnline)
            FilledButton.icon(
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Åimdi Senkronize Et'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: onSync,
            ),

          if (!isOnline)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.wifi_off_rounded,
                      color: AppColors.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ä°nternet baÄŸlantÄ±sÄ± yok. BaÄŸlantÄ± kurulduÄŸunda otomatik senkronize edilecek.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.primary, height: 1.4),
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
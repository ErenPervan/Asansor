import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asansor/core/widgets/app_bottom_nav_bar.dart';
import 'package:asansor/features/elevator/widgets/home/home_qr_fab.dart';
import 'package:asansor/core/providers/sync_status_provider.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final colors = AppThemeColors.of(context);

    Widget? banner;
    if (syncState == SyncState.offline) {
      banner = Container(
        color: colors.warningContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 16, color: colors.warning),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Çevrimdışı Mod – Değişiklikler kaydediliyor',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.warning,
              ),
            ),
          ],
        ),
      );
    } else if (syncState == SyncState.syncing) {
      banner = Container(
        color: colors.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Sunucu ile eşitleniyor...',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.primary,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: navigationShell),
          ?banner,
        ],
      ),
      floatingActionButton: QrFab(onPressed: () => context.push('/scan')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AppBottomNavBar(navigationShell: navigationShell),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/core/theme/app_colors.dart';

/// A slim amber banner that appears at the top of a screen whenever the device
/// has no internet connection.
///
/// Usage — drop it as the first child inside a `Column` that wraps your screen
/// body, or use it as a `persistentFooterWidget` / after the `AppBar`:
///
/// ```dart
/// body: Column(
///   children: [
///     const OfflineBanner(),
///     Expanded(child: ...),
///   ],
/// )
/// ```
///
/// The banner renders nothing while the device is online, so it is safe to
/// leave in place unconditionally.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) return const SizedBox.shrink();

    final colors = AppThemeColors.of(context);

    return Material(
      color: colors.warningContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 16, color: colors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Çevrimdışı Mod – Son yedeklenen veriler gösteriliyor',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors.warning,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

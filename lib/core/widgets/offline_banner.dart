import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_providers.dart';

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

    return Material(
      color: const Color(0xFFFEF3C7), // amber-100
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 16,
              color: Color(0xFF92400E), // amber-800
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Çevrimdışı Mod – Son yedeklenen veriler gösteriliyor',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF92400E), // amber-800
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

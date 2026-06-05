import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class NotificationRationaleSheet extends StatelessWidget {
  const NotificationRationaleSheet({super.key});

  /// Displays the sheet if the user hasn't determined notification permissions yet.
  static Future<void> checkAndShow(BuildContext context) async {
    final shouldShow = await NotificationService.instance.shouldShowRationale();
    if (!shouldShow || !context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
      ),
      builder: (context) => const NotificationRationaleSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Bildirimlere İzin Verin',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Size atanan yeni görevlerden, asansör arızalarından ve bakım güncellemelerinden anında haberdar olmak için bildirimlere izin vermeniz gerekmektedir.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppThemeColors.of(context).onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await NotificationService.instance.requestPermission();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('İzin Ver'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Daha Sonra',
                  style: TextStyle(color: AppThemeColors.of(context).onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

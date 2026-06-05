import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/auth/providers/auth_providers.dart';
import 'package:asansor/core/router/app_router.dart';

class LoadingView extends ConsumerWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(appAuthStateProvider);

    if (authState.status == AuthStatus.error) {
      return Scaffold(
        backgroundColor: AppThemeColors.of(context).background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Profil yüklenirken bir hata oluştu.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  authState.errorMessage ?? 'Bilinmeyen hata',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Çıkış Yap'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppThemeColors.of(context).background,
      body: Center(
        child: CircularProgressIndicator(
          color: AppThemeColors.of(context).primary,
        ),
      ),
    );
  }
}

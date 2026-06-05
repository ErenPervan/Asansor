import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';

class NotFoundView extends StatelessWidget {
  const NotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hata'),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 80,
                color: AppThemeColors.of(context).outline,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Sayfa Bulunamadı',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Aradığınız sayfa mevcut değil veya silinmiş.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppThemeColors.of(context).onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Ana Sayfaya Dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

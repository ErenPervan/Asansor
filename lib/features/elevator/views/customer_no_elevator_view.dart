import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/auth/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerNoElevatorView extends ConsumerWidget {
  const CustomerNoElevatorView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.elevator_rounded, color: colors.primaryDark),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Asansor',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: isLoading ? null : () => _confirmSignOut(context, ref),
            icon: Icon(Icons.logout_rounded, color: colors.error, size: 18),
            label: Text(
              'Çıkış',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(isLoading: isLoading),
                    const SizedBox(height: AppSpacing.lg),
                    _InfoCard(),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed:
                          isLoading ? null : () => _confirmSignOut(context, ref),
                      icon: isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onPrimary,
                              ),
                            )
                          : const Icon(Icons.logout_rounded),
                      label: Text(isLoading ? 'Çıkış yapılıyor...' : 'Oturumu Kapat'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: colors.primaryDark,
                        foregroundColor: colors.onPrimary,
                        textStyle: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final colors = AppThemeColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.logout_rounded, color: colors.error),
        title: const Text('Çıkış Yap'),
        content: const Text('Oturumu kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.16),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -50,
            child: Icon(
              Icons.elevator_rounded,
              size: 176,
              color: colors.onPrimary.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 126,
                height: 126,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 106,
                      height: 106,
                      decoration: BoxDecoration(
                        color: colors.onPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLowest,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.elevator_rounded,
                        color: colors.primaryDark,
                        size: 38,
                      ),
                    ),
                    Positioned(
                      top: 18,
                      right: 18,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.accentGold,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.surfaceContainerLowest,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.priority_high_rounded,
                          size: 16,
                          color: Color(0xFF241A00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Asansör Atanmamış',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Hesabınıza bağlı bir asansör kaydı bulunamadı.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _StatusPill(isLoading: isLoading),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLoading ? Icons.sync_rounded : Icons.pending_actions_rounded,
            color: AppColors.accentGold,
            size: 16,
          ),
          const SizedBox(width: 7),
          Text(
            isLoading ? 'Oturum kapatılıyor' : 'Atama bekleniyor',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primaryFixed.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.info_rounded, color: colors.primaryDark),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Asansör atandıktan sonra bakım, arıza ve durum bilgilerinize otomatik erişebilirsiniz. Atama için bina yöneticiniz veya sistem yetkilisi ile iletişime geçin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

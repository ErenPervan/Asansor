import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
// ── CustomerNoElevatorView ────────────────────────────────────────────────────

/// Shown to customers who have the `customer` role but no `elevator_id`
/// assigned to their profile yet.
///
/// Instructs the user to contact their building manager.
/// The only action available is signing out.
class CustomerNoElevatorView extends ConsumerStatefulWidget {
  const CustomerNoElevatorView({super.key});

  @override
  ConsumerState<CustomerNoElevatorView> createState() =>
      _CustomerNoElevatorViewState();
}

class _CustomerNoElevatorViewState
    extends ConsumerState<CustomerNoElevatorView> {
  // Navigation when elevator is assigned is now handled automatically
  // by GoRouter's redirect logic listening to appAuthStateProvider.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.of(context).background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              // ── Top bar with sign-out ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Asansor',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.0,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Çıkış Yap'),
                            content: Text(
                              'Oturumu kapatmak istediğinize emin misiniz?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text('İptal'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                ),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text('Çıkış Yap'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
                        }
                      },
                      icon: Icon(Icons.logout_outlined, size: 16),
                      label: Text('Çıkış Yap'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.outline,
                        textStyle: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Illustration area ─────────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.warningContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.elevator_outlined,
                  size: 52,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Title ─────────────────────────────────────────────────
              Text(
                'Asansör Atanmamış',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: 0.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // ── Description ───────────────────────────────────────────
              Text(
                'Hesabınıza henüz bir asansör tanımlanmamış.\n'
                'Lütfen bina yöneticiniz veya sistem adminiyle iletişime geçin.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Info card ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Asansör atandıktan sonra otomatik olarak '
                        'bakım ve durum bilgilerinize erişebilirsiniz.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Sign-out button ───────────────────────────────────────
              FilledButton.icon(
                onPressed: () async =>
                    await ref.read(authControllerProvider.notifier).signOut(),
                icon: Icon(Icons.logout_outlined),
                label: Text(
                  'Oturumu Kapat',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

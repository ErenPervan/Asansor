import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../admin/providers/profile_providers.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
// â”€â”€ CustomerNoElevatorView â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
  @override
  void initState() {
    super.initState();
    routerRoleNotifier.addListener(_checkElevatorId);
  }

  @override
  void dispose() {
    routerRoleNotifier.removeListener(_checkElevatorId);
    super.dispose();
  }

  void _checkElevatorId() {
    if (routerRoleNotifier.elevatorId != null) {
      context.go('/customer/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.of(context).background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              // â”€â”€ Top bar with sign-out â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Ã‡Ä±kÄ±ÅŸ Yap'),
                            content: Text(
                              'Oturumu kapatmak istediÄŸinize emin misiniz?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text('Ä°ptal'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                ),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text('Ã‡Ä±kÄ±ÅŸ Yap'),
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
                      label: Text('Ã‡Ä±kÄ±ÅŸ Yap'),
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

              // â”€â”€ Illustration area â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

              // â”€â”€ Title â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Text(
                'AsansÃ¶r AtanmamÄ±ÅŸ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // â”€â”€ Description â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Text(
                'HesabÄ±nÄ±za henÃ¼z bir asansÃ¶r tanÄ±mlanmamÄ±ÅŸ.\n'
                'LÃ¼tfen bina yÃ¶neticiniz veya sistem adminiyle iletiÅŸime geÃ§in.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // â”€â”€ Info card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                        'AsansÃ¶r atandÄ±ktan sonra otomatik olarak '
                        'bakÄ±m ve durum bilgilerinize eriÅŸebilirsiniz.',
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

              // â”€â”€ Sign-out button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

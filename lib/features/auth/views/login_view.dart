import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asansor/core/constants/app_durations.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/app_form_field.dart';
import 'package:asansor/features/auth/providers/auth_providers.dart';
import 'package:asansor/l10n/app_localizations.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  late final AnimationController _introCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutCubic));
    _introCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<dynamic>>(authControllerProvider, (_, next) {
      next.whenOrNull(
        data: (user) {
          if (user != null) context.go('/');
        },
        error: (error, _) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(error.toString().replaceFirst('Exception: ', '')),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                duration: AppDurations.snackBarError,
              ),
            );
        },
      );
    });

    if (MediaQuery.disableAnimationsOf(context)) {
      _introCtrl.value = 1;
    }

    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _BrandMark(),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Asansor',
                              style: textTheme.headlineMedium?.copyWith(
                                color: colors.primaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'OPERASYON\nYONETIMI',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.secondary.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                                height: 1.35,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Hesabiniza giris yapin',
                              style: textTheme.headlineMedium?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Bakim gorevleri, ariza kayitlari ve asansor '
                              'durumlarini guvenle yonetin.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.45,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _LoginPanel(
                              formKey: _formKey,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              obscurePassword: _obscurePassword,
                              isLoading: isLoading,
                              onSubmit: _submit,
                              onTogglePassword: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              l10n: l10n,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _SecureConnectionNote(
                              label: l10n.loginSecureConnection,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.elevator_rounded, color: Colors.white, size: 34),
          Positioned(
            top: 14,
            child: Container(
              width: 12,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.accentGold,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onSubmit,
    required this.onTogglePassword,
    required this.l10n,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onTogglePassword;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppFormField(
                controller: emailController,
                label: l10n.loginEmailLabel,
                hint: 'ornek@sirket.com',
                keyboardType: TextInputType.emailAddress,
                readOnly: isLoading,
                prefixIcon: const Icon(Icons.mail_outline_rounded),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.loginEmailValidationErrorEmpty;
                  }
                  if (!v.contains('@')) {
                    return l10n.loginEmailValidationErrorInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppFormField(
                controller: passwordController,
                label: l10n.loginPasswordLabel,
                hint: '••••••••',
                obscureText: obscurePassword,
                readOnly: isLoading,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  tooltip: obscurePassword ? 'Sifreyi goster' : 'Sifreyi gizle',
                  onPressed: isLoading ? null : onTogglePassword,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return l10n.loginPasswordValidationErrorEmpty;
                  }
                  if (v.length < 6) {
                    return l10n.loginPasswordValidationErrorLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: isLoading ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    disabledBackgroundColor: colors.primary.withValues(
                      alpha: 0.55,
                    ),
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.loginButton,
                              style: textTheme.labelLarge?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecureConnectionNote extends StatelessWidget {
  const _SecureConnectionNote({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 16,
          color: colors.onSurfaceVariant.withValues(alpha: 0.65),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: 0.65),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

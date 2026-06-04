import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';

import '../providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_form_field.dart';
import '../../../core/constants/app_durations.dart';
// ── Brand palette ──────────────────────────────────────────────────────────────

// ── Industrial grid background painter ────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Diagonal stripe accent painter ────────────────────────────────────────────

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.square;

    for (double i = -size.height; i < size.width + size.height; i += 60) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Rotating gear decoration ──────────────────────────────────────────────────

class _GearDecoration extends StatefulWidget {
  const _GearDecoration({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  State<_GearDecoration> createState() => _GearDecorationState();
}

class _GearDecorationState extends State<_GearDecoration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.rotate(
        angle: _ctrl.value * 2 * math.pi,
        child: Icon(
          Icons.settings_outlined,
          size: widget.size,
          color: Colors.white.withValues(alpha: widget.opacity),
        ),
      ),
    );
  }
}

// ── LoginView ──────────────────────────────────────────────────────────────────

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
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _slideCtrl.dispose();
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

    final isLoading = ref.watch(authControllerProvider).isLoading;
    final screenH = MediaQuery.of(context).size.height;
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colors.primary,
      body: Column(
        children: [
          // ── Crimson header (brand section) ──────────────────────────────
          SizedBox(
            height: (screenH * 0.38).clamp(220.0, 360.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Gradient background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryDark, AppColors.primary],
                      stops: [0.0, 1.0],
                    ),
                  ),
                ),
                // Industrial grid texture
                const CustomPaint(painter: _GridPainter()),
                // Diagonal stripes
                const CustomPaint(painter: _StripePainter()),
                // Decorative gears (background)
                Positioned(
                  right: -28,
                  top: -20,
                  child: _GearDecoration(size: 140, opacity: 0.07),
                ),
                Positioned(
                  left: -20,
                  bottom: 10,
                  child: _GearDecoration(size: 90, opacity: 0.06),
                ),
                // Top safe-area spacer
                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon in white circle
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.elevator_outlined,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'ASANSOR',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          l10n.appSubTitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── White form card (slides up) ─────────────────────────────────
          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x28000000),
                        blurRadius: 40,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card title
                          Text(
                            l10n.loginTitle,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.loginSubTitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // ── E-posta ──────────────────────────────────────
                          AppFormField(
                            controller: _emailController,
                            label: l10n.loginEmailLabel,
                            hint: 'ornek@sirket.com',
                            keyboardType: TextInputType.emailAddress,
                            readOnly: isLoading,
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              size: 18,
                            ),
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
                          const SizedBox(height: 20),

                          // ── Şifre ────────────────────────────────────────
                          AppFormField(
                            controller: _passwordController,
                            label: l10n.loginPasswordLabel,
                            hint: '••••••••',
                            obscureText: _obscurePassword,
                            readOnly: isLoading,
                            prefixIcon: const Icon(
                              Icons.lock_outlined,
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
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
                          const SizedBox(height: AppSpacing.xl),

                          // ── Login button ──────────────────────────────────
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: isLoading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                disabledBackgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.onPrimary,
                                      ),
                                    )
                                  : Text(
                                      l10n.loginButton,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                          ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Footer ────────────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 24,
                                height: 1,
                                color: colors.outlineVariant,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.loginSecureConnection,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      letterSpacing: 0.3,
                                    ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.lock_outlined,
                                size: 11,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 24,
                                height: 1,
                                color: colors.outlineVariant,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small helpers ──────────────────────────────────────────────────────────────


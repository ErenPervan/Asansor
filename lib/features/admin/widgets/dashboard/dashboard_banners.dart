import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

// ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ Conflict Banner ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬

class ConflictBanner extends StatelessWidget {
  const ConflictBanner({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final iconSize = (MediaQuery.textScalerOf(
      context,
    ).scale(52)).clamp(40.0, 72.0);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.errorContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.error.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: colors.error.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: colors.error,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count Senkronizasyon ÇakÖÃ‚Â±Ö¦Ş¸masÖÃ‚Â±',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onErrorContainer,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ÇözülmemiÖ¦Ş¸ çakÖÃ‚Â±Ö¦Ş¸malar var, incelemek için dokunun',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.onErrorContainer,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: colors.error,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ Add Elevator Banner ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬

class AddElevatorBanner extends StatelessWidget {
  const AddElevatorBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final iconSize = (MediaQuery.textScalerOf(
      context,
    ).scale(52)).clamp(40.0, 72.0);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.error,
                colors.errorContainer,
              ], // Just matching a general red gradient from theme
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.error.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: colors.onPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yeni Asansör Ekle',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'KayÖÃ‚Â±t oluÖ¦Ş¸tur ve QR kodu otomatik üret',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_rounded,
                      size: 14,
                      color: colors.onPrimary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'QR',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ Shared ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬ÃƒÂ¢Ã¢â‚¬Â─šÂ¬

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

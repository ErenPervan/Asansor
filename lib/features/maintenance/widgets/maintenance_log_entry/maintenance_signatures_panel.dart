import 'dart:math' as math;

import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import 'package:asansor/features/maintenance/widgets/maintenance_log_entry/maintenance_premium_panel.dart';

class MaintenanceSignaturesPanel extends StatelessWidget {
  const MaintenanceSignaturesPanel({
    super.key,
    required this.techSignatureController,
    required this.custSignatureController,
    required this.techSignatureError,
    required this.custSignatureError,
    required this.signatureShakeController,
    required this.onTechClear,
    required this.onCustClear,
    required this.onTechInteract,
    required this.onCustInteract,
  });

  final SignatureController techSignatureController;
  final SignatureController custSignatureController;
  final bool techSignatureError;
  final bool custSignatureError;
  final AnimationController signatureShakeController;
  final VoidCallback onTechClear;
  final VoidCallback onCustClear;
  final VoidCallback onTechInteract;
  final VoidCallback onCustInteract;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasError = techSignatureError || custSignatureError;

    return MaintenancePremiumPanel(
      title: l10n.maintenanceSignaturesSection,
      icon: Icons.draw_outlined,
      borderColor: hasError
          ? colors.errorContainer
          : colors.outlineVariant.withValues(alpha: 0.45),
      warning: hasError ? l10n.maintenanceSignatureError : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 620;
          final tech = _SignaturePad(
            label: l10n.maintenanceSignatureTechLabel,
            controller: techSignatureController,
            showError: techSignatureError,
            signatureShakeController: signatureShakeController,
            onClear: onTechClear,
            onInteract: onTechInteract,
          );
          final customer = _SignaturePad(
            label: l10n.maintenanceSignatureCustLabel,
            controller: custSignatureController,
            showError: custSignatureError,
            signatureShakeController: signatureShakeController,
            onClear: onCustClear,
            onInteract: onCustInteract,
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tech),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: customer),
              ],
            );
          }

          return Column(
            children: [
              tech,
              const SizedBox(height: AppSpacing.md),
              customer,
            ],
          );
        },
      ),
    );
  }
}

class _SignaturePad extends StatelessWidget {
  const _SignaturePad({
    required this.label,
    required this.controller,
    required this.showError,
    required this.signatureShakeController,
    required this.onClear,
    required this.onInteract,
  });

  final String label;
  final SignatureController controller;
  final bool showError;
  final AnimationController signatureShakeController;
  final VoidCallback onClear;
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: signatureShakeController,
      builder: (context, child) {
        final shake = showError
            ? math.sin(signatureShakeController.value * math.pi * 6) * 6
            : 0.0;
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: showError
                  ? colors.error.withValues(alpha: 0.05)
                  : colors.surfaceContainerLow,
              border: Border.all(
                color: showError
                    ? colors.error.withValues(alpha: 0.58)
                    : colors.outlineVariant,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Listener(
                  onPointerDown: (_) => onInteract(),
                  child: Signature(
                    controller: controller,
                    height: 150,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextButton(
                    onPressed: onClear,
                    child: Text(l10n.maintenanceSignatureClear),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

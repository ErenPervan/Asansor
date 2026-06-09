import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FaultActionBar extends StatelessWidget {
  const FaultActionBar({
    super.key,
    required this.fault,
    required this.isLoading,
    required this.onResolve,
    required this.onReopen,
  });

  final FaultReportModel fault;
  final bool isLoading;
  final VoidCallback onResolve;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.92),
          border: Border(
            top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.35)),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : fault.isResolved
                            ? onReopen
                            : () => context.pop(),
                    icon: Icon(
                      fault.isResolved
                          ? Icons.refresh_rounded
                          : Icons.arrow_back_rounded,
                    ),
                    label: Text(
                      fault.isResolved ? 'Yeniden Aç' : 'Geri Dön',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: colors.onSurface,
                      side: BorderSide(color: colors.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (!fault.isResolved) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onResolve,
                      icon: isLoading
                          ? SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colors.onPrimary,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(isLoading ? 'Kaydediliyor...' : 'Onarıldı İşaretle'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        backgroundColor: colors.primaryDark,
                        foregroundColor: colors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';

class StatsSection extends StatelessWidget {
  const StatsSection({
    super.key,
    required this.activeFaultCount,
    required this.completedCount,
    this.completedLabel = 'TAMAMLANAN',
  });

  final int activeFaultCount;
  final int completedCount;
  final String completedLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            semanticsLabel: 'Acik ariza sayisi: $activeFaultCount',
            value: '$activeFaultCount',
            title: 'Acik Arizalar',
            subtitle: 'Aktif takip',
            icon: Icons.warning_rounded,
            accentColor: AppThemeColors.of(context).error,
            backgroundColor: AppThemeColors.of(
              context,
            ).errorContainer.withValues(alpha: 0.32),
            elevated: false,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _KpiCard(
            semanticsLabel: 'Tamamlanan bakim sayisi: $completedCount',
            value: '$completedCount',
            title: 'Tamamlanan',
            subtitle: completedLabel,
            icon: Icons.verified_rounded,
            accentColor: AppThemeColors.of(context).primary,
            backgroundColor: AppThemeColors.of(context).surfaceContainerLowest,
            elevated: true,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.semanticsLabel,
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.elevated,
  });

  final String semanticsLabel;
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: semanticsLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 156),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: elevated
                  ? colors.outlineVariant.withValues(alpha: 0.35)
                  : accentColor.withValues(alpha: 0.18),
            ),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: accentColor, size: 28),
                    Text(
                      value,
                      style: textTheme.headlineSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.labelLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: elevated
                            ? colors.onSurfaceVariant
                            : accentColor.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ElevatorsShortcutCard extends StatelessWidget {
  const ElevatorsShortcutCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Asansorler listesine git',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primary, colors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.24),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tum Asansor Envanteri',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sistemdeki tum asansorleri listele ve ara.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onPrimary.withValues(alpha: 0.78),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: colors.onPrimary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

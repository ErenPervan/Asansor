import 'dart:io';
import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/maintenance/views/widgets/maintenance_premium_panel.dart';
import 'package:asansor/l10n/app_localizations.dart';

class MaintenancePhotoEvidencePanel extends StatelessWidget {
  const MaintenancePhotoEvidencePanel({
    super.key,
    required this.photoPaths,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final List<String> photoPaths;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return MaintenancePremiumPanel(
      title: l10n.maintenancePhotosSection,
      icon: Icons.photo_library_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${photoPaths.length} Fotoğraf',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: Column(
        children: [
          if (photoPaths.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
              ),
              itemCount: photoPaths.length,
              itemBuilder: (context, index) {
                return _PhotoTile(
                  path: photoPaths[index],
                  onRemove: () => onRemove(index),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                l10n.maintenancePhotosEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: _EvidenceButton(
                  icon: Icons.photo_camera_outlined,
                  label: l10n.maintenancePhotosCamera,
                  onTap: onCamera,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _EvidenceButton(
                  icon: Icons.image_outlined,
                  label: l10n.maintenancePhotosGallery,
                  onTap: onGallery,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: colors.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: l10n.maintenancePhotosRemoveTooltip,
            style: IconButton.styleFrom(
              backgroundColor: colors.error.withValues(alpha: 0.9),
              foregroundColor: colors.onError,
              minimumSize: const Size(28, 28),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceButton extends StatelessWidget {
  const _EvidenceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primaryDark,
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
        backgroundColor: colors.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

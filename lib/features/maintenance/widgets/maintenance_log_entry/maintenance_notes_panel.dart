import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'package:asansor/features/maintenance/widgets/maintenance_log_entry/maintenance_premium_panel.dart';

class MaintenanceNotesPanel extends StatelessWidget {
  const MaintenanceNotesPanel({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return MaintenancePremiumPanel(
      title: l10n.maintenanceNotesSection,
      icon: Icons.notes_outlined,
      child: TextFormField(
        controller: controller,
        minLines: 5,
        maxLines: 7,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
        decoration: InputDecoration(
          hintText: l10n.maintenanceNotesHint,
          filled: true,
          fillColor: colors.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: colors.primary.withValues(alpha: 0.42),
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

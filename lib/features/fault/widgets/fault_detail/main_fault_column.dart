import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:flutter/material.dart';

import 'package:asansor/features/fault/widgets/fault_detail/fault_dates_grid.dart';
import 'package:asansor/features/fault/widgets/fault_detail/fault_photo_panel.dart';
import 'package:asansor/features/fault/widgets/fault_detail/fault_premium_panel.dart';

class MainFaultColumn extends StatelessWidget {
  const MainFaultColumn({
    super.key,
    required this.fault,
    required this.notesController,
  });

  final FaultReportModel fault;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Column(
      children: [
        FaultPremiumPanel(
          accentColor: fault.isResolved ? colors.success : colors.error,
          title: 'Arıza Açıklaması',
          icon: Icons.report_problem_outlined,
          iconColor: fault.isResolved ? colors.success : colors.error,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.32),
                  ),
                ),
                child: Text(
                  fault.description.isNotEmpty
                      ? fault.description
                      : 'Açıklama girilmedi.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FaultDatesGrid(fault: fault),
            ],
          ),
        ),
        if (fault.photoUrl?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.md),
          FaultPhotoPanel(photoUrl: fault.photoUrl!),
        ],
        const SizedBox(height: AppSpacing.md),
        FaultPremiumPanel(
          title: 'Çözüm Notu',
          icon: Icons.edit_note_rounded,
          iconColor: colors.primaryDark,
          child: fault.isResolved
              ? Text(
                  fault.resolutionNotes?.isNotEmpty == true
                      ? fault.resolutionNotes!
                      : 'Çözüm notu girilmedi.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Müdahale detaylarını ve değiştirilen parçaları buraya giriniz.',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: notesController,
                      minLines: 5,
                      maxLines: 7,
                      decoration: InputDecoration(
                        hintText:
                            'Örn: Kapı motoru kontrol edildi, sensör bağlantıları yenilendi...',
                        filled: true,
                        fillColor: colors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colors.outlineVariant.withValues(alpha: 0.4),
                          ),
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
                  ],
                ),
        ),
      ],
    );
  }
}

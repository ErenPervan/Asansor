import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'calendar_helpers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../elevator/models/elevator_model.dart';
import '../../models/profile_model.dart';
import '../../models/schedule_model.dart';

// ── CalendarTaskCard ─────────────────────────────────────────────────────────

class CalendarTaskCard extends StatelessWidget {
  const CalendarTaskCard({
    super.key,
    required this.schedule,
    this.elevator,
    this.technician,
    this.onCancel,
  });

  final ScheduleModel schedule;
  final ElevatorModel? elevator;
  final ProfileModel? technician;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final pColor = getPriorityColor(schedule.priority);
    final sColor = getStatusColor(schedule.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Priority stripe
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: pColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: time + badges
                      Row(
                        children: [
                          Text(
                            formatTime(schedule.scheduledDate),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: pColor,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          PriorityBadge(priority: schedule.priority),
                          const Spacer(),
                          StatusBadge(
                            label: getStatusLabel(schedule.status),
                            color: sColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Elevator name
                      Text(
                        elevator?.buildingName ??
                            'Asansör ${schedule.elevatorId.substring(0, 6)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Address
                      if (elevator?.address != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: AppColors.outline,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  elevator!.address!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontSize: 12,
                                        color: AppColors.outline,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      // Technician row
                      Row(
                        children: [
                          const Icon(
                            Icons.engineering_outlined,
                            size: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            technician?.displayName ??
                                'Teknisyen ${schedule.technicianId.substring(0, 6)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          if (schedule.notes != null &&
                              schedule.notes!.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(
                              Icons.notes_outlined,
                              size: 13,
                              color: AppColors.outline,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                schedule.notes!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontSize: 12,
                                      color: AppColors.outline,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Cancel button
                      if (onCancel != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onCancel,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 14),
                            label: Text(
                              'İptal Et',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                            ),
                          ),
                        ),
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

// ── Small badge widgets ───────────────────────────────────────────────────────

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = getPriorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        getPriorityLabel(priority),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── _AssignTaskSheet ──────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/widgets/empty_state.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/status_tokens.dart';
import 'package:asansor/core/utils/elevator_utils.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/admin/models/schedule_model.dart';
import 'package:asansor/features/admin/widgets/dashboard/dashboard_banners.dart';

// ── Schedule List ─────────────────────────────────────────────────────────────

class DashboardScheduleList extends StatelessWidget {
  const DashboardScheduleList({
    super.key,
    required this.schedules,
    required this.elevators,
  });

  final AsyncValue<List<ScheduleModel>> schedules;
  final List<ElevatorModel>? elevators;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tüm Görevler',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            letterSpacing: 0.0,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        schedules.when(
          loading: () => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(color: colors.primary),
            ),
          ),
          error: (e, _) => ErrorBanner(
            message: e.toString().replaceFirst('Exception: ', ''),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                message: 'Henüz atanmış görev bulunmuyor.',
                icon: Icons.event_note_outlined,
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final schedule = list[i];
                final elevator = findElevator(schedule.elevatorId, elevators);
                return DashboardScheduleCard(
                  schedule: schedule,
                  elevatorName: elevator?.buildingName ?? 'Asansör',
                  address: elevator?.address,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class DashboardScheduleCard extends StatelessWidget {
  const DashboardScheduleCard({
    super.key,
    required this.schedule,
    required this.elevatorName,
    this.address,
  });

  final ScheduleModel schedule;
  final String elevatorName;
  final String? address;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status indicator dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: StatusTokens.scheduleForegroundDynamic(
                context,
                schedule.status,
              ),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  elevatorName,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    address!,
                    style: textTheme.bodySmall?.copyWith(color: colors.outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 13,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _shortDate(schedule.scheduledDate),
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.person_outline,
                      size: 13,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        schedule.technicianId.length >= 8
                            ? '…${schedule.technicianId.substring(schedule.technicianId.length - 8)}'
                            : schedule.technicianId,
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: StatusTokens.scheduleBackgroundDynamic(
                context,
                schedule.status,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              StatusTokens.scheduleLabel(schedule.status),
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: StatusTokens.scheduleForegroundDynamic(
                  context,
                  schedule.status,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

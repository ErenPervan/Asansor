import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tüm Görevler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        schedules.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (e, _) => ErrorBanner(
            message: e.toString().replaceFirst('Exception: ', ''),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.event_note_outlined, color: AppColors.outline),
                    SizedBox(width: 12),
                    Text(
                      'Henüz atanmış görev bulunmuyor.',
                      style: TextStyle(color: AppColors.outline),
                    ),
                  ],
                ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              color: StatusTokens.scheduleForeground(schedule.status),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    address!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _shortDate(schedule.scheduledDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.person_outline,
                      size: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        schedule.technicianId.length >= 8
                            ? '…${schedule.technicianId.substring(schedule.technicianId.length - 8)}'
                            : schedule.technicianId,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: StatusTokens.scheduleBackground(schedule.status),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              StatusTokens.scheduleLabel(schedule.status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: StatusTokens.scheduleForeground(schedule.status),
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

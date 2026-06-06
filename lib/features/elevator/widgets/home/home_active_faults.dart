import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/utils/elevator_utils.dart';
import 'package:asansor/core/widgets/empty_state.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';

class ActiveFaultsSection extends StatelessWidget {
  const ActiveFaultsSection({
    super.key,
    required this.activeFaults,
    required this.elevators,
  });

  final AsyncValue<List<FaultReportModel>> activeFaults;
  final List<ElevatorModel>? elevators;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Acil Mudahale Bekleyenler',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/faults'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Tumunu Gor'),
            ),
            activeFaults.maybeWhen(
              data: (faults) => Container(
                margin: const EdgeInsets.only(left: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${faults.length} Aktif',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        activeFaults.when(
          loading: () => const LoadingState(shrinkWrap: true),
          error: (e, _) =>
              ErrorState(message: e.toString().replaceFirst('Exception: ', '')),
          data: (faults) {
            if (faults.isEmpty) {
              return const EmptyState(
                icon: Icons.check_circle_outline,
                message: 'Aktif arıza bulunmuyor.',
              );
            }

            final visibleFaults = faults.take(3).toList();

            return Column(
              children: [
                for (final fault in visibleFaults) ...[
                  _FaultListItem(
                    fault: fault,
                    elevator: findElevator(fault.elevatorId, elevators),
                    onTap: () => context.push('/fault/${fault.id}'),
                  ),
                  if (fault != visibleFaults.last)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FaultListItem extends StatelessWidget {
  const _FaultListItem({
    required this.fault,
    required this.elevator,
    required this.onTap,
  });

  final FaultReportModel fault;
  final ElevatorModel? elevator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final buildingName = elevator?.buildingName ?? 'Asansor';
    final description = fault.description.isNotEmpty
        ? fault.description
        : 'Ariza bildirimi alindi.';
    final isNew = DateTime.now().difference(fault.reportedAt).inMinutes < 30;

    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isNew
                        ? colors.errorContainer
                        : AppColors.accentGold.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isNew ? Icons.elevator_rounded : Icons.build_rounded,
                    color: isNew ? colors.error : AppColors.accentGold,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buildingName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isNew
                            ? colors.errorContainer.withValues(alpha: 0.65)
                            : AppColors.accentGold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isNew ? 'Kritik' : 'Yuksek',
                        style: textTheme.labelSmall?.copyWith(
                          color: isNew ? colors.error : colors.warning,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(fault.reportedAt),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.outline,
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

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 1) return '${diff.inDays} gun once';
  if (diff.inHours >= 1) return '${diff.inHours} sa once';
  if (diff.inMinutes >= 1) return '${diff.inMinutes} dk once';
  return 'Simdi';
}

class FaultCard extends StatelessWidget {
  const FaultCard({
    super.key,
    required this.fault,
    required this.buildingName,
    required this.address,
    required this.cardWidth,
    this.onTap,
  });

  final FaultReportModel fault;
  final String buildingName;
  final String address;
  final double cardWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final description = fault.description.isNotEmpty
        ? fault.description
        : 'Arıza bildirimi alındı.';

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'ACİL ARIZA',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _timeAgo(fault.reportedAt),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  buildingName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: colors.outline),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

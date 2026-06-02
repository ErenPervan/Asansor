import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/utils/elevator_utils.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:asansor/core/widgets/empty_state.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Açık Arızalar',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppThemeColors.of(context).onSurface,
                letterSpacing: -0.5,
              ),
            ),
            activeFaults.maybeWhen(
              data: (faults) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppThemeColors.of(
                    context,
                  ).primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${faults.length} Aktif',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppThemeColors.of(context).primary,
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Content
        activeFaults.when(
          loading: () => const LoadingState(),
          error: (e, _) =>
              ErrorState(message: e.toString().replaceFirst('Exception: ', '')),
          data: (faults) {
            if (faults.isEmpty) {
              return const EmptyState(
                icon: Icons.check_circle_outline,
                message: 'Aktif arıza bulunmuyor.',
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth * 0.85).clamp(
                  260.0,
                  400.0,
                );
                return SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: EdgeInsets.zero,
                    itemCount: faults.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, i) {
                      final elevator = findElevator(
                        faults[i].elevatorId,
                        elevators,
                      );
                      return FaultCard(
                        fault: faults[i],
                        buildingName: elevator?.buildingName ?? 'Asansör',
                        address: elevator?.address ?? faults[i].description,
                        cardWidth: cardWidth,
                        onTap: () => context.push('/fault/${faults[i].id}'),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class FaultCard extends StatefulWidget {
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
  State<FaultCard> createState() => FaultCardState();
}

class FaultCardState extends State<FaultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final description = widget.fault.description.isNotEmpty
        ? widget.fault.description
        : 'Arıza bildirimi alındı.';
    final isNew =
        DateTime.now().difference(widget.fault.reportedAt).inMinutes < 15;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final glowAlpha = isNew ? 0.08 + (_pulse.value * 0.14) : 0.06;
          return Container(
            width: widget.cardWidth,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colors.error.withValues(alpha: glowAlpha),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: colors.onSurface.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header band
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [colors.primary, colors.error],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'ACİL ARIZA',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  // Time ago
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _timeAgo(widget.fault.reportedAt),
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Building name
                  Text(
                    widget.buildingName,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Address
                  if (widget.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: colors.outline,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            widget.address,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      description,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 1) return '${diff.inDays} gün önce';
  if (diff.inHours >= 1) return '${diff.inHours} sa önce';
  if (diff.inMinutes >= 1) return '${diff.inMinutes} dk önce';
  return 'Şimdi';
}

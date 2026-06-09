import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/models/schedule_model.dart';
import 'package:asansor/features/admin/providers/admin_providers.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:asansor/features/fault/providers/fault_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

const _colorFault = AppColors.error;
const _colorMaintenance = AppColors.warningLight;
const _colorHealthy = AppColors.successLight;
const _panelLine = Color(0xFFE1E8F0);

enum _MarkerStatus { fault, maintenance, healthy }

class AdminMapView extends ConsumerStatefulWidget {
  const AdminMapView({super.key});

  @override
  ConsumerState<AdminMapView> createState() => _AdminMapViewState();
}

class _AdminMapViewState extends ConsumerState<AdminMapView> {
  final _mapController = MapController();
  static const _defaultCenter = LatLng(41.0082, 28.9784);
  bool _hasAutoFitted = false;

  _MarkerStatus _getStatus({
    required String elevatorId,
    required AsyncValue<List<FaultReportModel>> activeFaults,
    required AsyncValue<List<ScheduleModel>> allSchedules,
  }) {
    final hasFault =
        activeFaults.valueOrNull?.any((f) => f.elevatorId == elevatorId) ??
        false;
    if (hasFault) return _MarkerStatus.fault;

    final today = DateTime.now();
    final hasTodayMaintenance =
        allSchedules.valueOrNull?.any((s) {
          if (s.elevatorId != elevatorId ||
              s.status != ScheduleStatus.pending) {
            return false;
          }
          final d = s.scheduledDate.toLocal();
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        }) ??
        false;

    return hasTodayMaintenance
        ? _MarkerStatus.maintenance
        : _MarkerStatus.healthy;
  }

  void _autoFitCamera(List<ElevatorModel> elevators) {
    if (_hasAutoFitted) return;
    final located = elevators.where((e) => e.hasMappableLocation).toList();
    if (located.isEmpty) return;

    _hasAutoFitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (located.length == 1) {
        _mapController.move(
          LatLng(located.first.latitude!, located.first.longitude!),
          14,
        );
        return;
      }

      final points = located
          .map((e) => LatLng(e.latitude!, e.longitude!))
          .toList();
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(56, 120, 56, 190),
        ),
      );
    });
  }

  List<Marker> _buildMarkers({
    required BuildContext context,
    required List<ElevatorModel> elevators,
    required AsyncValue<List<FaultReportModel>> activeFaults,
    required AsyncValue<List<ScheduleModel>> allSchedules,
  }) {
    final markers = <Marker>[];
    for (final elevator in elevators) {
      if (!elevator.hasMappableLocation) continue;

      final status = _getStatus(
        elevatorId: elevator.id,
        activeFaults: activeFaults,
        allSchedules: allSchedules,
      );

      markers.add(
        Marker(
          point: LatLng(elevator.latitude!, elevator.longitude!),
          width: 58,
          height: 58,
          child: GestureDetector(
            onTap: () => _showElevatorSheet(context, elevator, status),
            child: Center(child: _MarkerPin(status: status)),
          ),
        ),
      );
    }
    return markers;
  }

  void _showElevatorSheet(
    BuildContext context,
    ElevatorModel elevator,
    _MarkerStatus status,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ElevatorSheet(
        elevator: elevator,
        status: status,
        onViewDetails: () {
          Navigator.of(context, rootNavigator: true).pop();
          context.push('/elevator/${elevator.id}');
        },
      ),
    );
  }

  void _refresh() {
    _hasAutoFitted = false;
    ref.invalidate(elevatorsProvider);
    ref.invalidate(activeFaultsProvider);
    ref.invalidate(allSchedulesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final elevatorsAsync = ref.watch(elevatorsProvider);
    final activeFaults = ref.watch(activeFaultsProvider);
    final allSchedules = ref.watch(allSchedulesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Icon(Icons.elevator_rounded, color: colors.primary),
            const SizedBox(width: 10),
            Text(
              'Asansör',
              style: textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Text(
                  'Operasyon Yönetimi',
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _refresh,
                  tooltip: 'Yenile',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
      body: elevatorsAsync.when(
        loading: () => const LoadingState(isList: false, height: 400),
        error: (e, _) => _ErrorBody(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: _refresh,
        ),
        data: (elevators) {
          _autoFitCamera(elevators);

          final markers = _buildMarkers(
            context: context,
            elevators: elevators,
            activeFaults: activeFaults,
            allSchedules: allSchedules,
          );
          final locatedCount = elevators
              .where((e) => e.hasMappableLocation)
              .length;
          final unmappedCount = elevators.length - locatedCount;
          final faultCount = activeFaults.valueOrNull?.length ?? 0;
          final todayMaintenanceCount = _todayMaintenanceCount(allSchedules);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: 11,
                  minZoom: 4,
                  maxZoom: 19,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.asansor',
                    maxZoom: 19,
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.background.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _MapHeaderOverlay(
                  locatedCount: locatedCount,
                  totalCount: elevators.length,
                  faultCount: faultCount,
                  maintenanceCount: todayMaintenanceCount,
                  onRefresh: _refresh,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _LegendPanel(unmappedCount: unmappedCount),
              ),
            ],
          );
        },
      ),
    );
  }

  int _todayMaintenanceCount(AsyncValue<List<ScheduleModel>> schedules) {
    final today = DateTime.now();
    return schedules.valueOrNull
            ?.where((s) {
              final d = s.scheduledDate.toLocal();
              return s.status == ScheduleStatus.pending &&
                  d.year == today.year &&
                  d.month == today.month &&
                  d.day == today.day;
            })
            .length ??
        0;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

class _MapHeaderOverlay extends StatelessWidget {
  const _MapHeaderOverlay({
    required this.locatedCount,
    required this.totalCount,
    required this.faultCount,
    required this.maintenanceCount,
    required this.onRefresh,
  });

  final int locatedCount;
  final int totalCount;
  final int faultCount;
  final int maintenanceCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _panelLine),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderTitle(onRefresh: onRefresh),
                    const SizedBox(height: AppSpacing.md),
                    _MetricsWrap(
                      locatedCount: locatedCount,
                      totalCount: totalCount,
                      faultCount: faultCount,
                      maintenanceCount: maintenanceCount,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _HeaderTitle(onRefresh: onRefresh)),
                    _MetricsWrap(
                      locatedCount: locatedCount,
                      totalCount: totalCount,
                      faultCount: faultCount,
                      maintenanceCount: maintenanceCount,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.map_rounded, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Canlı Operasyon Haritası',
                style: textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Aktif arıza, bugünkü bakım ve sağlıklı asansör konumları',
                style: textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Yenile',
          icon: Icon(Icons.refresh_rounded, color: colors.primary),
        ),
      ],
    );
  }
}

class _MetricsWrap extends StatelessWidget {
  const _MetricsWrap({
    required this.locatedCount,
    required this.totalCount,
    required this.faultCount,
    required this.maintenanceCount,
  });

  final int locatedCount;
  final int totalCount;
  final int faultCount;
  final int maintenanceCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _MiniMetric(
          label: 'Haritada',
          value: '$locatedCount/$totalCount',
          color: AppColors.primary,
        ),
        _MiniMetric(
          label: 'Aktif Arıza',
          value: '$faultCount',
          color: _colorFault,
        ),
        _MiniMetric(
          label: 'Bugün Bakım',
          value: '$maintenanceCount',
          color: _colorMaintenance,
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkerPin extends StatelessWidget {
  const _MarkerPin({required this.status});

  final _MarkerStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, pulsing) = switch (status) {
      _MarkerStatus.fault => (_colorFault, Icons.warning_rounded, true),
      _MarkerStatus.maintenance => (
        _colorMaintenance,
        Icons.build_rounded,
        false,
      ),
      _MarkerStatus.healthy => (_colorHealthy, Icons.elevator_outlined, false),
    };

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pulsing)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _LegendPanel extends StatelessWidget {
  const _LegendPanel({required this.unmappedCount});

  final int unmappedCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _panelLine),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: const [
                  _LegendItem(
                    color: _colorFault,
                    icon: Icons.warning_rounded,
                    label: 'Aktif Arıza',
                  ),
                  _LegendItem(
                    color: _colorMaintenance,
                    icon: Icons.build_rounded,
                    label: 'Bugün Bakım',
                  ),
                  _LegendItem(
                    color: _colorHealthy,
                    icon: Icons.elevator_outlined,
                    label: 'Normal',
                  ),
                ],
              ),
              if (unmappedCount > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_off_rounded,
                        size: 18,
                        color: colors.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Koordinatı eksik $unmappedCount asansör haritada gösterilmiyor.',
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 13),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ElevatorSheet extends StatelessWidget {
  const _ElevatorSheet({
    required this.elevator,
    required this.status,
    required this.onViewDetails,
  });

  final ElevatorModel elevator;
  final _MarkerStatus status;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final (statusLabel, statusColor, statusIcon) = switch (status) {
      _MarkerStatus.fault => ('Aktif Arıza', _colorFault, Icons.warning_rounded),
      _MarkerStatus.maintenance => (
        'Bugün Bakım',
        _colorMaintenance,
        Icons.build_rounded,
      ),
      _MarkerStatus.healthy => ('Normal', _colorHealthy, Icons.check_rounded),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelLine),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          elevator.buildingName,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colors.onSurface,
                            letterSpacing: 0,
                          ),
                        ),
                        if (elevator.address != null &&
                            elevator.address!.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            elevator.address!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusChip(label: statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _InfoStrip(elevator: elevator),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: onViewDetails,
                  icon: const Icon(Icons.visibility_rounded, size: 19),
                  label: Text(
                    'Detaya Git',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelLine),
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          _InfoPair(
            icon: Icons.precision_manufacturing_rounded,
            label: 'Model',
            value: elevator.model ?? 'Belirtilmedi',
          ),
          _InfoPair(
            icon: Icons.monitor_weight_rounded,
            label: 'Kapasite',
            value: elevator.capacity == null
                ? 'Belirtilmedi'
                : '${elevator.capacity} kg',
          ),
          _InfoPair(
            icon: Icons.location_on_rounded,
            label: 'Koordinat',
            value:
                '${elevator.latitude?.toStringAsFixed(4)}, ${elevator.longitude?.toStringAsFixed(4)}',
          ),
        ],
      ),
    );
  }
}

class _InfoPair extends StatelessWidget {
  const _InfoPair({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: colors.outline,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              value,
              style: textTheme.labelMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_off_outlined,
                color: colors.onErrorContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

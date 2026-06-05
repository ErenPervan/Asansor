import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:latlong2/latlong.dart';

import '../../elevator/models/elevator_model.dart';

import '../../elevator/providers/elevator_providers.dart';

import '../../fault/models/fault_report_model.dart';

import '../../fault/providers/fault_providers.dart';

import '../models/schedule_model.dart';

import '../providers/admin_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/widgets/loading_state.dart';

// Marker colours (match Google Maps palette for familiarity)
const _colorFault = AppColors.error;
const _colorMaintenance = AppColors.warningLight;
const _colorHealthy = AppColors.successLight;

// ── Marker status enum ────────────────────────────────────────────────────────

enum _MarkerStatus { fault, maintenance, healthy }

// ── AdminMapView ──────────────────────────────────────────────────────────────

/// Live Operation Map — powered by flutter_map + OpenStreetMap (no API key).
///
/// Marker colours:
///  • RED    — elevator has at least one unresolved fault.
///  • YELLOW — no fault, but a pending maintenance is scheduled for today.
///  • GREEN  — healthy, no active issues.
///
/// Tapping a marker opens a bottom sheet with building info and a
/// "Detayları Gör" button that navigates to `/elevator/:id`.
class AdminMapView extends ConsumerStatefulWidget {
  const AdminMapView({super.key});

  @override
  ConsumerState<AdminMapView> createState() => _AdminMapViewState();
}

class _AdminMapViewState extends ConsumerState<AdminMapView> {
  final _mapController = MapController();

  /// Istanbul — used when no elevator has coordinates yet.
  static const _defaultCenter = LatLng(41.0082, 28.9784);

  /// Prevents the auto-fit from firing on every rebuild.
  bool _hasAutoFitted = false;

  // ── Status derivation ─────────────────────────────────────────────────────

  _MarkerStatus _getStatus({
    required String elevatorId,
    required AsyncValue<List<FaultReportModel>> activeFaults,
    required AsyncValue<List<ScheduleModel>> allSchedules,
  }) {
    // Priority 1 – any unresolved fault → RED
    final hasFault =
        activeFaults.valueOrNull?.any((f) => f.elevatorId == elevatorId) ??
        false;
    if (hasFault) return _MarkerStatus.fault;

    // Priority 2 – pending maintenance scheduled for today → YELLOW
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

  // ── Camera fit ────────────────────────────────────────────────────────────

  /// After the first data load, moves the camera to encompass all markers.
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
          padding: const EdgeInsets.fromLTRB(48, 80, 48, 200),
        ),
      );
    });
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────

  void _showElevatorSheet(
    BuildContext context,
    ElevatorModel elevator,
    _MarkerStatus status,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
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

  // ── Marker building ───────────────────────────────────────────────────────

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
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => _showElevatorSheet(context, elevator, status),
            child: _MarkerPin(status: status),
          ),
        ),
      );
    }

    return markers;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final elevatorsAsync = ref.watch(elevatorsProvider);
    final activeFaults = ref.watch(activeFaultsProvider);
    final allSchedules = ref.watch(allSchedulesProvider);

    return Scaffold(
      backgroundColor: AppThemeColors.of(context).background,
      appBar: AppBar(
        backgroundColor: AppThemeColors.of(context).primary,
        foregroundColor: AppThemeColors.of(context).onPrimary,
        elevation: 0,
        title: Text(
          'Canlı Operasyon Haritası',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.0,
            color: AppThemeColors.of(context).onPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Yenile',
            onPressed: () {
              _hasAutoFitted = false;
              ref.invalidate(elevatorsProvider);
              ref.invalidate(activeFaultsProvider);
              ref.invalidate(allSchedulesProvider);
            },
          ),
        ],
      ),
      body: elevatorsAsync.when(
        loading: () => const LoadingState(isList: false, height: 400),
        error: (e, _) => _ErrorBody(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () {
            _hasAutoFitted = false;
            ref.invalidate(elevatorsProvider);
          },
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

          return Stack(
            children: [
              // ── Map ───────────────────────────────────────────────────────
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
                    // OpenStreetMap tile usage policy requires identifying
                    // the app. Use your real package name in production.
                    userAgentPackageName: 'com.example.asansor',
                    maxZoom: 19,
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              // ── Stats overlay (top-left) ──────────────────────────────────
              Positioned(
                top: 12,
                left: 12,
                child: _StatsOverlay(
                  locatedCount: locatedCount,
                  totalCount: elevators.length,
                  faultCount: activeFaults.valueOrNull?.length ?? 0,
                ),
              ),

              // ── Legend sheet (bottom) ─────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _LegendSheet(unmappedCount: unmappedCount),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

// ── Marker pin widget ─────────────────────────────────────────────────────────

class _MarkerPin extends StatelessWidget {
  const _MarkerPin({required this.status});

  final _MarkerStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      _MarkerStatus.fault => (_colorFault, Icons.warning_rounded),
      _MarkerStatus.maintenance => (_colorMaintenance, Icons.build_rounded),
      _MarkerStatus.healthy => (_colorHealthy, Icons.elevator_outlined),
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

// ── Elevator bottom sheet ─────────────────────────────────────────────────────

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
    final (statusLabel, statusColor) = switch (status) {
      _MarkerStatus.fault => ('Aktif Arıza', _colorFault),
      _MarkerStatus.maintenance => ('Bugün Bakım', _colorMaintenance),
      _MarkerStatus.healthy => ('Normal', _colorHealthy),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppThemeColors.of(context).outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Status badge + building name row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    elevator.buildingName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppThemeColors.of(context).onSurface,
                      letterSpacing: 0.0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            // Address
            if (elevator.address != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: AppThemeColors.of(context).outline,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      elevator.address!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppThemeColors.of(context).outline,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  'Detayları Gör',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppThemeColors.of(context).primary,
                  foregroundColor: AppThemeColors.of(context).onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats overlay ─────────────────────────────────────────────────────────────

class _StatsOverlay extends StatelessWidget {
  const _StatsOverlay({
    required this.locatedCount,
    required this.totalCount,
    required this.faultCount,
  });

  final int locatedCount;
  final int totalCount;
  final int faultCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppThemeColors.of(context).onSurface.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$locatedCount / $totalCount asansör haritada',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppThemeColors.of(context).onSurface,
            ),
          ),
          if (faultCount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _colorFault,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$faultCount aktif arıza',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _colorFault,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _LegendSheet extends StatelessWidget {
  const _LegendSheet({required this.unmappedCount});

  final int unmappedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: AppThemeColors.of(context).surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppThemeColors.of(context).onSurface.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppThemeColors.of(context).outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Legend row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _LegendItem(
                color: _colorFault,
                icon: Icons.warning_rounded,
                label: 'Arıza',
                sublabel: 'Çözülmemiş',
              ),
              _LegendItem(
                color: _colorMaintenance,
                icon: Icons.build_rounded,
                label: 'Bakım',
                sublabel: 'Bugün',
              ),
              _LegendItem(
                color: _colorHealthy,
                icon: Icons.elevator_outlined,
                label: 'Normal',
                sublabel: 'Sorunsuz',
              ),
            ],
          ),

          // Unmapped note
          if (unmappedCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppThemeColors.of(context).background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppThemeColors.of(
                    context,
                  ).outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 14,
                    color: AppThemeColors.of(context).onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$unmappedCount asansörün koordinatı eksik — haritada gösterilmiyor.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppThemeColors.of(context).onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String sublabel;

  @override
  Widget build(BuildContext context) {
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
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 13),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppThemeColors.of(context).onSurface,
              ),
            ),
            Text(
              sublabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppThemeColors.of(context).outline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppThemeColors.of(context).errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_off_outlined,
                color: AppThemeColors.of(context).onErrorContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppThemeColors.of(context).onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: FilledButton.styleFrom(
                backgroundColor: AppThemeColors.of(context).primary,
                foregroundColor: AppThemeColors.of(context).onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

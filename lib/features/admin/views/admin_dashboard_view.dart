import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../elevator/models/elevator_model.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../models/schedule_model.dart';
import '../providers/admin_providers.dart';
import '../repositories/admin_repository.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _primary = Color(0xFFB91C1C);
const _error = Color(0xFFDC2626);
const _errorContainer = Color(0xFFFEE2E2);
const _onErrorContainer = Color(0xFF991B1B);
const _success = Color(0xFF166534);
const _successContainer = Color(0xFFDCFCE7);
const _warning = Color(0xFF92400E);
const _warningContainer = Color(0xFFFEF3C7);
const _surfaceContainerLowest = Colors.white;
const _surfaceContainer = Color(0xFFF1F5F9);
const _outlineVariant = Color(0xFFE2E8F0);
const _onSurface = Color(0xFF0F172A);
const _onSurfaceVariant = Color(0xFF475569);
const _outline = Color(0xFF94A3B8);
const _background = Color(0xFFF9FAFB);

// ── Helpers ───────────────────────────────────────────────────────────────────

String _statusLabel(String status) {
  switch (status) {
    case 'in_progress':
      return 'Devam Ediyor';
    case 'completed':
      return 'Tamamlandı';
    case 'cancelled':
      return 'İptal Edildi';
    default:
      return 'Bekliyor';
  }
}

Color _statusBg(String status) {
  switch (status) {
    case 'in_progress':
      return _warningContainer;
    case 'completed':
      return _successContainer;
    case 'cancelled':
      return _errorContainer;
    default:
      return _surfaceContainer;
  }
}

Color _statusFg(String status) {
  switch (status) {
    case 'in_progress':
      return _warning;
    case 'completed':
      return _success;
    case 'cancelled':
      return _onErrorContainer;
    default:
      return _onSurfaceVariant;
  }
}

String _shortDate(DateTime dt) {
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return 'Bugün ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

ElevatorModel? _findElevator(String id, List<ElevatorModel>? list) {
  if (list == null) return null;
  try {
    return list.firstWhere((e) => e.id == id);
  } catch (_) {
    return null;
  }
}

// ── AdminDashboardView ────────────────────────────────────────────────────────

class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final schedules = ref.watch(allSchedulesProvider);
    final elevators = ref.watch(elevatorsProvider);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Admin Paneli',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Yenile',
            onPressed: () {
              ref.invalidate(adminStatsProvider);
              ref.invalidate(allSchedulesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          ref.invalidate(allSchedulesProvider);
          ref.invalidate(elevatorsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatsGrid(stats: stats),
            const SizedBox(height: 16),
            _AddElevatorBanner(
                onTap: () => context.push('/admin/add-elevator')),
            const SizedBox(height: 16),
            _MapPreviewCard(onTap: () => context.push('/admin/map')),
            const SizedBox(height: 12),
            _UserManagementCard(onTap: () => context.push('/admin/users')),
            const SizedBox(height: 12),
            _CalendarCard(onTap: () => context.push('/admin/calendar')),
            const SizedBox(height: 12),
            _MasterCalendarCard(
                onTap: () => context.push('/admin/master-calendar')),
            const SizedBox(height: 12),
            _TechnicianDirCard(
                onTap: () => context.push('/admin/technicians')),
            const SizedBox(height: 32),
            _ScheduleList(
              schedules: schedules,
              elevators: elevators.valueOrNull,
            ),
            const SizedBox(height: 100),
          ],
        ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/assign'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.assignment_ind_outlined),
        label: const Text(
          'Görev Ata',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final AsyncValue<AdminStats> stats;

  @override
  Widget build(BuildContext context) {
    return stats.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: _primary),
        ),
      ),
      error: (e, _) => _ErrorBanner(
        message: e.toString().replaceFirst('Exception: ', ''),
      ),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Genel Bakış',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              // Subtle "live" dot
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: _success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Canlı',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Top row: brand card (crimson) + fault alert ──────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '${s.totalElevators}',
                  label: 'Toplam Asansör',
                  icon: Icons.elevator_outlined,
                  variant: _StatVariant.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: '${s.activeFaults}',
                  label: 'Açık Arıza',
                  icon: Icons.warning_amber_rounded,
                  variant: s.activeFaults > 0
                      ? _StatVariant.critical
                      : _StatVariant.neutral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Bottom row: completed + pending ──────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '${s.completedThisMonth}',
                  label: 'Tamamlanan (Bu Ay)',
                  icon: Icons.check_circle_outline,
                  variant: _StatVariant.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: '${s.pendingThisMonth}',
                  label: 'Bekleyen (Bu Ay)',
                  icon: Icons.pending_outlined,
                  variant: _StatVariant.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _StatVariant { brand, critical, success, warning, neutral }

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.variant,
  });

  final String value;
  final String label;
  final IconData icon;
  final _StatVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, iconBg, iconFg, valueFg, labelFg, gradient) = switch (variant) {
      _StatVariant.brand => (
          _primary,
          Colors.white.withValues(alpha: 0.15),
          Colors.white,
          Colors.white,
          Colors.white70,
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
          ) as Gradient?,
        ),
      _StatVariant.critical => (
          const Color(0xFFFFF1F2), // red-50
          const Color(0xFFFFE4E4),
          _error,
          _error,
          const Color(0xFF9F1239), // rose-800
          null,
        ),
      _StatVariant.success => (
          const Color(0xFFF0FDF4), // green-50
          const Color(0xFFDCFCE7),
          _success,
          _success,
          const Color(0xFF14532D),
          null,
        ),
      _StatVariant.warning => (
          const Color(0xFFFFFBEB), // amber-50
          const Color(0xFFFEF3C7),
          _warning,
          _warning,
          const Color(0xFF78350F),
          null,
        ),
      _StatVariant.neutral => (
          _surfaceContainerLowest,
          _surfaceContainer,
          _outline,
          _onSurface,
          _onSurfaceVariant,
          null,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: gradient == null
            ? Border.all(color: _outlineVariant.withValues(alpha: 0.6))
            : null,
        boxShadow: [
          BoxShadow(
            color: (gradient != null ? _primary : Colors.black)
                .withValues(alpha: gradient != null ? 0.18 : 0.04),
            blurRadius: gradient != null ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon in a soft pill
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconFg, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: valueFg,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: labelFg,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map Preview Card ──────────────────────────────────────────────────────────

class _MapPreviewCard extends StatelessWidget {
  const _MapPreviewCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF004180), Color(0xFF295999)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF004180).withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.map_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canlı Operasyon Haritası',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tüm asansörleri gerçek zamanlı haritada görüntüle',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── User Management Card ──────────────────────────────────────────────────────

class _UserManagementCard extends StatelessWidget {
  const _UserManagementCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outlineVariant.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.manage_accounts_outlined,
                  color: _primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kullanıcı Yönetimi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Teknisyen, müşteri ve admin rollerini yönet',
                      style: TextStyle(
                        fontSize: 12,
                        color: _onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _outline,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Calendar Card ─────────────────────────────────────────────────────────────

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outlineVariant.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B6B3A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: Color(0xFF1B6B3A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bakım Takvimi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Görevleri planla, teknisyen ata ve takvimi yönet',
                      style: TextStyle(
                        fontSize: 12,
                        color: _onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _outline,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Master Calendar Card ──────────────────────────────────────────────────────

class _MasterCalendarCard extends StatelessWidget {
  const _MasterCalendarCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _primary.withValues(alpha: 0.06),
                _primary.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _primary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: _primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ana Takvim',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tüm görevlerin genel görünümü, filtrele ve izle',
                      style: TextStyle(
                        fontSize: 12,
                        color: _onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _primary,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add Elevator Banner ───────────────────────────────────────────────────────

class _AddElevatorBanner extends StatelessWidget {
  const _AddElevatorBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFB91C1C), Color(0xFF991B1B)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yeni Asansör Ekle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Kayıt oluştur ve QR kodu otomatik üret',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_rounded,
                        size: 14, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'QR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Technician Directory Card ─────────────────────────────────────────────────

class _TechnicianDirCard extends StatelessWidget {
  const _TechnicianDirCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outlineVariant.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF0369A1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.engineering_outlined,
                  color: Color(0xFF0369A1),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teknisyen Yönetimi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ekip durumu, iş yükü ve günlük görev takibi',
                      style: TextStyle(
                        fontSize: 12,
                        color: _onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _outline,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Schedule List ─────────────────────────────────────────────────────────────

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({
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
            color: _onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        schedules.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: _primary),
            ),
          ),
          error: (e, _) => _ErrorBanner(
            message: e.toString().replaceFirst('Exception: ', ''),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.event_note_outlined, color: _outline),
                    SizedBox(width: 12),
                    Text(
                      'Henüz atanmış görev bulunmuyor.',
                      style: TextStyle(color: _outline),
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
                final elevator = _findElevator(schedule.elevatorId, elevators);
                return _ScheduleCard(
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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
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
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.4)),
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
              color: _statusFg(schedule.status),
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
                    color: _onSurface,
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
                      color: _outline,
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
                      color: _onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _shortDate(schedule.scheduledDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.person_outline,
                      size: 13,
                      color: _onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        schedule.technicianId.length >= 8
                            ? '…${schedule.technicianId.substring(schedule.technicianId.length - 8)}'
                            : schedule.technicianId,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _onSurfaceVariant,
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
              color: _statusBg(schedule.status),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _statusLabel(schedule.status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _statusFg(schedule.status),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

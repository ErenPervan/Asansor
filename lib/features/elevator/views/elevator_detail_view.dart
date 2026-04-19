import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/services/pdf_report_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../elevator/models/elevator_model.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../../fault/providers/fault_providers.dart';
import '../../maintenance/models/maintenance_log_model.dart';
import '../../maintenance/providers/maintenance_providers.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _primary = Color(0xFFB91C1C);
const _primaryFixed = Color(0xFFFFE4E4);
const _primaryContainer = Color(0xFF991B1B);
const _onPrimaryContainer = Color(0xFFFFE4E4);
const _secondary = Color(0xFFEF4444);
const _secondaryContainer = Color(0xFFFEE2E2);
const _onSecondaryContainer = Color(0xFF991B1B);
const _error = Color(0xFFDC2626);
const _errorContainer = Color(0xFFFEE2E2);
const _onErrorContainer = Color(0xFF991B1B);
const _surfaceContainerLowest = Colors.white;
const _surfaceContainerLow = Color(0xFFF8FAFC);
const _surfaceContainer = Color(0xFFF1F5F9);
const _surfaceContainerHighest = Color(0xFFE2E8F0);
const _onSurface = Color(0xFF0F172A);
const _onSurfaceVariant = Color(0xFF475569);
const _outline = Color(0xFF94A3B8);
const _outlineVariant = Color(0xFFE2E8F0);
const _background = Color(0xFFF9FAFB);

// ── Turkish month abbreviations (avoids intl locale init) ────────────────────

const _monthsTr = [
  'OCA',
  'ŞUB',
  'MAR',
  'NİS',
  'MAY',
  'HAZ',
  'TEM',
  'AĞU',
  'EYL',
  'EKİ',
  'KAS',
  'ARA',
];

String _fmtDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.day.toString().padLeft(2, '0')} '
      '${_monthsTr[local.month - 1]} '
      '${local.year}';
}

// ── ElevatorDetailView ────────────────────────────────────────────────────────

class ElevatorDetailView extends ConsumerWidget {
  const ElevatorDetailView({super.key, required this.elevatorId});

  final String elevatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elevatorAsync = ref.watch(elevatorByIdProvider(elevatorId));

    return Scaffold(
      backgroundColor: _background,
      // ── Top App Bar ──────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Asansör Detayları',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: _onSurface,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: _primary),
            onPressed: () {},
          ),
        ],
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: elevatorAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _primary)),
        error: (err, _) => _ErrorBody(
          message: err.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(elevatorByIdProvider(elevatorId)),
        ),
        data: (elevator) => _DetailScrollBody(
          elevator: elevator,
          elevatorId: elevatorId,
          onReportFault: () {
            ref.invalidate(faultControllerProvider);
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => _ReportFaultSheet(elevatorId: elevatorId),
            );
          },
          onLogMaintenance: () {
            ref.invalidate(maintenanceControllerProvider);
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => _LogMaintenanceSheet(elevatorId: elevatorId),
            );
          },
        ),
      ),

      // ── Bottom Navigation ─────────────────────────────────────────────────
      bottomNavigationBar: const _BottomNav(),
    );
  }
}

// ── Scrollable body (shown when elevator data is loaded) ─────────────────────

class _DetailScrollBody extends StatelessWidget {
  const _DetailScrollBody({
    required this.elevator,
    required this.elevatorId,
    required this.onReportFault,
    required this.onLogMaintenance,
  });

  final ElevatorModel elevator;
  final String elevatorId;
  final VoidCallback onReportFault;
  final VoidCallback onLogMaintenance;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1 ── Header identity card ───────────────────────────────────────
          _HeaderCard(elevator: elevator),
          const SizedBox(height: 24),

          // 2 ── Quick action buttons ───────────────────────────────────────
          _ActionButtons(
            onReportFault: onReportFault,
            onLogMaintenance: onLogMaintenance,
          ),
          const SizedBox(height: 24),

          // 3 ── System monitor + next maintenance ─────────────────────────
          const _SystemMonitorSection(),
          const SizedBox(height: 24),

          // 4 ── Maintenance history timeline ───────────────────────────────
          _MaintenanceHistorySection(
            elevatorId: elevatorId,
            elevator: elevator,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── 1. Header Identity Card ───────────────────────────────────────────────────
// Stitch: <section class="bg-surface-container-lowest rounded-xl p-6 shadow-...">

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF191C1D).withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge — top right (Stack equivalent)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + name/address
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Elevator icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _primaryFixed, // primary-fixed: #D6E3FF
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.elevator_outlined,
                        color: _primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            elevator.buildingName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: _onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  elevator.address ?? 'Adres belirtilmemiş',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Dynamic status badge
              _StatusBadge(status: elevator.status),
            ],
          ),

          // Divider + static metadata grid
          const SizedBox(height: 20),
          Divider(height: 1, color: _outlineVariant.withValues(alpha: 0.15)),
          const SizedBox(height: 20),

          // Static meta grid (Model + Capacity) — not in DB schema yet
          Row(
            children: [
              Expanded(
                child: _MetaCell(
                  label: 'MODEL',
                  value: '—', // TODO: add model field to DB schema
                ),
              ),
              Expanded(
                child: _MetaCell(
                  label: 'KAPASİTE',
                  value: '—', // TODO: add capacity field to DB schema
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _outline,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _onSurface,
          ),
        ),
      ],
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────
// Stitch: <span class="bg-emerald-600 text-white ... rounded-full">DURUM: AKTİF</span>

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status.toLowerCase()) {
      'active' => (
        'DURUM: AKTİF',
        const Color(0xFF059669), // emerald-600
        Colors.white,
      ),
      'faulty' => ('DURUM: ARIZALI', _errorContainer, _onErrorContainer),
      'under_maintenance' => (
        'DURUM: BAKIMDA',
        const Color(0xFFFFF3CD),
        const Color(0xFF856404),
      ),
      'inactive' => ('DURUM: PASİF', _surfaceContainer, _outline),
      _ => ('DURUM: BİLİNMİYOR', _surfaceContainer, _outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── 2. Quick Action Buttons ───────────────────────────────────────────────────
// Stitch: <section class="grid grid-cols-2 gap-4">

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onReportFault,
    required this.onLogMaintenance,
  });

  final VoidCallback onReportFault;
  final VoidCallback onLogMaintenance;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // "Arıza Bildir" — error-container background
        Expanded(
          child: _ActionCard(
            onTap: onReportFault,
            backgroundColor: _errorContainer,
            iconContainerColor: _error.withValues(alpha: 0.12),
            icon: Icons.warning_rounded,
            iconColor: _error,
            label: 'Arıza Bildir',
            labelColor: _onErrorContainer,
          ),
        ),
        const SizedBox(width: 16),
        // "Bakım Ekle" — primary background
        Expanded(
          child: _ActionCard(
            onTap: onLogMaintenance,
            backgroundColor: _primary,
            iconContainerColor: Colors.white.withValues(alpha: 0.12),
            icon: Icons.assignment_outlined,
            iconColor: Colors.white,
            label: 'Bakım Ekle',
            labelColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.onTap,
    required this.backgroundColor,
    required this.iconContainerColor,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconContainerColor;
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconContainerColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 3. System Monitor Section (static) ───────────────────────────────────────
// Stitch: <section class="grid grid-cols-1 md:grid-cols-3 gap-6">
// No live data from our schema yet — rendered as static placeholders.

class _SystemMonitorSection extends StatelessWidget {
  const _SystemMonitorSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── "Sistem İzleme" panel ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sistem İzleme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Pulsing analytics icon (static representation)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primaryFixed.withValues(alpha: 0.4),
                        ),
                      ),
                      const Icon(
                        Icons.analytics_outlined,
                        color: _primary,
                        size: 40,
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  // Status indicators
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusIndicator(
                        label: 'Bağlantı Kararlı',
                        color: const Color(0xFF10B981), // emerald-500
                      ),
                      const SizedBox(height: 8),
                      _StatusIndicator(
                        label: 'Güç Kaynağı Normal',
                        color: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Stat chips
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'GÜNLÜK TUR',
                      value: '—', // TODO: fetch from telemetry
                      valueColor: _primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatChip(
                      label: 'SON ARIZA',
                      value: '—', // TODO: compute from fault_reports
                      valueColor: _secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── "Sıradaki Bakım" panel ────────────────────────────────────────
        // Stitch: bg-primary-container text-on-primary-container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Background icon
              Positioned(
                right: -16,
                bottom: -16,
                child: Icon(
                  Icons.engineering_outlined,
                  size: 100,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIRADAKİ BAKIM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _onPrimaryContainer.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '—',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '—', // TODO: add scheduled_maintenance table
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Periyodik Genel Revizyon',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Randevu Düzenle',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _onSurface,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 4. Maintenance History Timeline ──────────────────────────────────────────
// Stitch: <section class="space-y-4"> with timeline CSS ::before pseudo-element

class _MaintenanceHistorySection extends ConsumerStatefulWidget {
  const _MaintenanceHistorySection({
    required this.elevatorId,
    required this.elevator,
  });

  final String elevatorId;
  final ElevatorModel elevator;

  @override
  ConsumerState<_MaintenanceHistorySection> createState() =>
      _MaintenanceHistorySectionState();
}

class _MaintenanceHistorySectionState
    extends ConsumerState<_MaintenanceHistorySection> {
  bool _generatingPdf = false;

  Future<void> _generateAndPreviewPdf() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      final logs = await repo.getLogsForReport(widget.elevatorId);
      final doc = await generateElevatorReport(widget.elevator, logs);
      final bytes = await doc.save();
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF oluşturulamadı: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _error,
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(logsByElevatorProvider(widget.elevatorId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bakım Geçmişi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _onSurface,
                letterSpacing: -0.4,
              ),
            ),
            Row(
              children: [
                // ── PDF Report button ──────────────────────────────────
                Tooltip(
                  message: 'PDF Rapor Oluştur (Son 6 Ay)',
                  child: _generatingPdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primary,
                          ),
                        )
                      : IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 22,
                            color: _primary,
                          ),
                          onPressed: _generateAndPreviewPdf,
                        ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Yenile',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.refresh, size: 18, color: _outline),
                  onPressed: () =>
                      ref.invalidate(logsByElevatorProvider(widget.elevatorId)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Timeline content
        logsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: _primary),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              err.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(color: _onErrorContainer),
            ),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 40, color: _outlineVariant),
                      SizedBox(height: 12),
                      Text(
                        'Henüz bakım kaydı yok.',
                        style: TextStyle(
                          color: _outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Timeline list — vertical line drawn as left-column Container
            return Column(
              children: logs.asMap().entries.map((entry) {
                return _TimelineItem(
                  log: entry.value,
                  isLast: entry.key == logs.length - 1,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Timeline item ─────────────────────────────────────────────────────────────
// Stitch: <div class="relative pl-8 ..."> with ::before vertical line + dot

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.log, required this.isLast});

  final MaintenanceLogModel log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight ensures the connecting line fills the full card height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left column: dot + connector line ──────────────────────────
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 6),
                // Dot with ring effect (ring-4 ring-surface → white border)
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    // Approved → primary dot; pending → outline-variant dot
                    color: log.isApproved ? _primary : _outlineVariant,
                    shape: BoxShape.circle,
                    border: Border.all(color: _background, width: 3),
                  ),
                ),
                // Connector line (hidden on last item)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: _outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),

          // ── Right column: card ─────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 16, bottom: isLast ? 0 : 24),
              child: _TimelineCard(log: log),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.log});

  final MaintenanceLogModel log;

  @override
  Widget build(BuildContext context) {
    final dateStr = _fmtDate(log.maintenanceDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + technician row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  // Approved uses primary colour, pending uses outline
                  color: log.isApproved ? _primary : _outline,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 12,
                      color: _onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      // Only UUID is available; show shortened form.
                      // TODO: resolve to display name from profiles table.
                      log.technicianId.length > 8
                          ? log.technicianId.substring(0, 8)
                          : log.technicianId,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Notes text (italic like the Stitch design)
          Text(
            '"${log.notes ?? 'Not belirtilmemiş'}"',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _onSurface,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Chips row
          Row(
            children: [
              _Chip(
                label: log.isApproved ? 'ONAYLANDI' : 'BEKLİYOR',
                bg: log.isApproved
                    ? _secondaryContainer // secondary-container
                    : _surfaceContainer,
                fg: log.isApproved
                    ? _onSecondaryContainer // on-secondary-container
                    : _onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────
// Stitch: <nav class="fixed bottom-0 ... flex justify-around">

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF191C1D).withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _NavItem(icon: Icons.analytics_outlined, label: 'Status'),
              _NavItem(icon: Icons.history, label: 'History', isActive: true),
              _NavItem(icon: Icons.report_problem_outlined, label: 'Faults'),
              _NavItem(icon: Icons.group_outlined, label: 'Team'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _primary : const Color(0xFF94A3B8);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

// ── Report Fault Bottom Sheet ─────────────────────────────────────────────────

class _ReportFaultSheet extends ConsumerStatefulWidget {
  const _ReportFaultSheet({required this.elevatorId});

  final String elevatorId;

  @override
  ConsumerState<_ReportFaultSheet> createState() => _ReportFaultSheetState();
}

class _ReportFaultSheetState extends ConsumerState<_ReportFaultSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(faultControllerProvider.notifier)
        .reportFault(
          elevatorId: widget.elevatorId,
          description: _descController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<dynamic>>(faultControllerProvider, (previous, next) {
      if (previous?.isLoading != true) return;
      next.whenOrNull(
        data: (fault) {
          if (fault == null) return;
          ref.invalidate(activeFaultsProvider);
          ref.invalidate(faultsByElevatorProvider(widget.elevatorId));
          if (!context.mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Arıza başarıyla bildirildi.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF155724),
            ),
          );
        },
        error: (err, _) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString().replaceFirst('Exception: ', '')),
              behavior: SnackBarBehavior.floating,
              backgroundColor: _error,
            ),
          );
        },
      );
    });

    final isLoading = ref.watch(faultControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_amber_outlined,
                        color: _onErrorContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Arıza Bildir',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _onSurface,
                          ),
                        ),
                        Text(
                          'Gözlemlenen arızayı açıklayın.',
                          style: TextStyle(fontSize: 13, color: _outline),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  minLines: 3,
                  textInputAction: TextInputAction.newline,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Arıza Açıklaması',
                    hintText: 'Arızayı detaylı açıklayın...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Lütfen bir açıklama girin.';
                    }
                    if (v.trim().length < 10) {
                      return 'Açıklama en az 10 karakter olmalıdır.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Arızayı Gönder',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
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

// ── Log Maintenance Bottom Sheet ──────────────────────────────────────────────

class _LogMaintenanceSheet extends ConsumerStatefulWidget {
  const _LogMaintenanceSheet({required this.elevatorId});

  final String elevatorId;

  @override
  ConsumerState<_LogMaintenanceSheet> createState() =>
      _LogMaintenanceSheetState();
}

class _LogMaintenanceSheetState extends ConsumerState<_LogMaintenanceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(authControllerProvider).valueOrNull?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum bilgisi alınamadı. Lütfen tekrar giriş yapın.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _error,
        ),
      );
      return;
    }
    ref
        .read(maintenanceControllerProvider.notifier)
        .addLog(
          elevatorId: widget.elevatorId,
          technicianId: userId,
          notes: _notesController.text.trim(),
          maintenanceDate: DateTime.now(),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<dynamic>>(maintenanceControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.isLoading != true) return;
      next.whenOrNull(
        data: (log) {
          if (log == null) return;
          ref.invalidate(logsByElevatorProvider(widget.elevatorId));
          ref.invalidate(pendingMaintenanceProvider);
          ref.invalidate(completedTodayCountProvider);
          if (!context.mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bakım kaydı başarıyla eklendi.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF155724),
            ),
          );
        },
        error: (err, _) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString().replaceFirst('Exception: ', '')),
              behavior: SnackBarBehavior.floating,
              backgroundColor: _error,
            ),
          );
        },
      );
    });

    final isLoading = ref.watch(maintenanceControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.build_outlined, color: _primary),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bakım Ekle',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _onSurface,
                          ),
                        ),
                        Text(
                          'Yapılan bakımı kaydedin.',
                          style: TextStyle(fontSize: 13, color: _outline),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  minLines: 3,
                  textInputAction: TextInputAction.newline,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Bakım Notları',
                    hintText: 'Yapılan işlemleri açıklayın...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Lütfen bakım notları girin.';
                    }
                    if (v.trim().length < 10) {
                      return 'Notlar en az 10 karakter olmalıdır.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Bakımı Kaydet',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
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

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: _error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: FilledButton.styleFrom(backgroundColor: _primary),
            ),
          ],
        ),
      ),
    );
  }
}

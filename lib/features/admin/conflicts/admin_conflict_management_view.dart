import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_conflict_provider.dart';

// ── Design tokens (aligned with Ascent Industrial design system) ─────────────
const _primary = Color(0xFF004180);
const _onPrimary = Colors.white;
const _surface = Color(0xFFF8F9FA);
const _surfaceContainerLowest = Colors.white;

// Local change section tint (warm red)
const _onSurface = Color(0xFF191C1D);
const _onSurfaceVariant = Color(0xFF424752);
const _error = Color(0xFFBA1A1A);

// Local change section tint (warm red)
const _localBg = Color(0xFFFFF1F2);
const _localLabel = Color(0xFF93000A);
const _localAccent = Color(0xFFBA1A1A);

// Remote state section tint (cool blue)
const _remoteBg = Color(0xFFF0F4FF);
const _remoteLabel = Color(0xFF0D4686);
const _remoteAccent = Color(0xFF004180);

// Pending chip
const _pendingBg = Color(0xFFFEF3C7);
const _pendingFg = Color(0xFF92400E);

// ─────────────────────────────────────────────────────────────────────────────

class AdminConflictManagementView extends ConsumerWidget {
  const AdminConflictManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncConflicts = ref.watch(adminConflictProvider);

    return Scaffold(
      backgroundColor: _surface,
      body: asyncConflicts.when(
        loading: () => const _LoadingState(),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (conflicts) => _ConflictBody(conflicts: conflicts),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _ConflictBody extends StatelessWidget {
  const _ConflictBody({required this.conflicts});
  final List<ConflictReport> conflicts;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _ConflictAppBar(conflictCount: conflicts.length),
        if (conflicts.isEmpty)
          const SliverFillRemaining(child: _EmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            sliver: SliverList.separated(
              itemCount: conflicts.length,
              separatorBuilder: (context, i) => const SizedBox(height: 16),
              itemBuilder: (context, index) =>
                  _ConflictCard(report: conflicts[index]),
            ),
          ),
      ],
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────

class _ConflictAppBar extends StatelessWidget {
  const _ConflictAppBar({required this.conflictCount});
  final int conflictCount;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      elevation: 0,
      backgroundColor: _primary,
      foregroundColor: _onPrimary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primary, Color(0xFF002D59)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Veri Çakışmaları',
                style: TextStyle(
                  color: _onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: conflictCount > 0
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    conflictCount > 0
                        ? '$conflictCount Bekleyen Çakışma'
                        : 'Tüm veriler senkronize',
                    style: TextStyle(
                      color: _onPrimary.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        title: const Text(
          'Veri Çakışmaları',
          style: TextStyle(
            color: _onPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
      ),
    );
  }
}

// ── Conflict Card ─────────────────────────────────────────────────────────────

class _ConflictCard extends ConsumerWidget {
  const _ConflictCard({required this.report});
  final ConflictReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(adminConflictProvider.notifier);
    final isLoading = ref.watch(adminConflictProvider).isLoading;

    final elevatorId = report.localPayload['id'] as String? ?? report.elevatorId;
    final localStatus = report.localPayload['status']?.toString() ?? '—';
    final remoteStatus = report.remotePayload['status']?.toString() ?? '—';
    final localDate = _formatDate(report.localPayload['updated_at']?.toString());
    final remoteDate = _formatDate(report.remotePayload['updated_at']?.toString());

    // Additional fields from payloads
    final localExtra = _extraFields(report.localPayload);
    final remoteExtra = _extraFields(report.remotePayload);

    return Container(
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _onSurface.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.elevator_outlined,
                    color: _primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asansör: ${elevatorId.length > 16 ? '${elevatorId.substring(0, 8)}…' : elevatorId}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        _formatDate(report.createdAt.toIso8601String()),
                        style: const TextStyle(
                          fontSize: 11,
                          color: _onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // BEKLEYEN chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _pendingBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'BEKLEYEN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _pendingFg,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Comparison Panels ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Local panel
                Expanded(
                  child: _ComparisonPanel(
                    label: 'Yerel Değişiklik',
                    icon: Icons.phone_android_rounded,
                    backgroundColor: _localBg,
                    accentColor: _localAccent,
                    labelColor: _localLabel,
                    status: localStatus,
                    date: localDate,
                    extraFields: localExtra,
                  ),
                ),
                const SizedBox(width: 8),
                // Remote panel
                Expanded(
                  child: _ComparisonPanel(
                    label: 'Uzak Durum',
                    icon: Icons.cloud_outlined,
                    backgroundColor: _remoteBg,
                    accentColor: _remoteAccent,
                    labelColor: _remoteLabel,
                    status: remoteStatus,
                    date: remoteDate,
                    extraFields: remoteExtra,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Action Buttons ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Row(
              children: [
                // Keep Remote
                Expanded(
                  child: _ActionButton(
                    label: 'Uzakı Koru',
                    icon: Icons.cloud_done_outlined,
                    backgroundColor: _remoteBg,
                    foregroundColor: _remoteAccent,
                    isLoading: isLoading,
                    onPressed: () => notifier.resolveConflict(
                      report: report,
                      chosenPayload: report.remotePayload,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Accept Local
                Expanded(
                  child: _ActionButton(
                    label: 'Yereli Kabul Et',
                    icon: Icons.check_circle_outline_rounded,
                    backgroundColor: _error,
                    foregroundColor: Colors.white,
                    isLoading: isLoading,
                    onPressed: () => notifier.resolveConflict(
                      report: report,
                      chosenPayload: report.localPayload,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  Map<String, String> _extraFields(Map<String, dynamic> payload) {
    const excluded = {'id', 'base_version', 'updated_at', 'status'};
    final result = <String, String>{};
    for (final entry in payload.entries) {
      if (!excluded.contains(entry.key) && result.length < 3) {
        result[entry.key] = entry.value?.toString() ?? '—';
      }
    }
    return result;
  }
}

// ── Comparison Panel ──────────────────────────────────────────────────────────

class _ComparisonPanel extends StatelessWidget {
  const _ComparisonPanel({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
    required this.labelColor,
    required this.status,
    required this.date,
    required this.extraFields,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color accentColor;
  final Color labelColor;
  final String status;
  final String date;
  final Map<String, String> extraFields;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 14),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: labelColor,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DataRow(label: 'DURUM', value: status, labelColor: labelColor),
          const SizedBox(height: 6),
          _DataRow(label: 'TARİH', value: date, labelColor: labelColor),
          for (final entry in extraFields.entries) ...[
            const SizedBox(height: 6),
            _DataRow(
              label: entry.key.toUpperCase().replaceAll('_', ' '),
              value: entry.value,
              labelColor: labelColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.value,
    required this.labelColor,
  });

  final String label;
  final String value;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: labelColor.withValues(alpha: 0.7),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _onSurface,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 120),
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          minimumSize: const Size(double.infinity, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF166534).withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF166534),
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Çakışma yok',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tüm veriler senkronize —\nsistem tamamen uyumlu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading & Error States ────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: _primary),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Bir hata oluştu',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../elevator/providers/elevator_providers.dart';
import '../models/fault_report_model.dart';
import '../providers/fault_providers.dart';

// ── Local colour tokens (matches global theme) ──────────────────────────────
const _crimson = Color(0xFFB91C1C);
const _crimsonDark = Color(0xFF991B1B);
const _crimsonLight = Color(0xFFDC2626);
const _success = Color(0xFF16A34A);
const _successContainer = Color(0xFFDCFCE7);
const _onSurface = Color(0xFF0F172A);
const _onSurfaceVariant = Color(0xFF475569);
const _outline = Color(0xFF94A3B8);
const _outlineVariant = Color(0xFFE2E8F0);
const _surface = Colors.white;
const _background = Color(0xFFF9FAFB);
const _surfaceContainer = Color(0xFFF1F5F9);

class FaultDetailView extends ConsumerWidget {
  const FaultDetailView({super.key, required this.faultId});

  final String faultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faultAsync = ref.watch(faultByIdProvider(faultId));

    return faultAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Arıza Detayı')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: _crimson),
              const SizedBox(height: 12),
              Text(
                'Arıza yüklenemedi',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: _onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                e.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(faultByIdProvider(faultId)),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
      data: (fault) => _FaultDetailScaffold(fault: fault),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FaultDetailScaffold extends ConsumerStatefulWidget {
  const _FaultDetailScaffold({required this.fault});

  final FaultReportModel fault;

  @override
  ConsumerState<_FaultDetailScaffold> createState() =>
      _FaultDetailScaffoldState();
}

class _FaultDetailScaffoldState extends ConsumerState<_FaultDetailScaffold> {
  final _notesController = TextEditingController();
  bool _notesExpanded = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fault = widget.fault;
    final elevatorAsync = ref.watch(elevatorByIdProvider(fault.elevatorId));
    final updateState = ref.watch(faultUpdateControllerProvider);

    final elevatorName = elevatorAsync.valueOrNull?.buildingName ?? '—';
    final elevatorAddress = elevatorAsync.valueOrNull?.address ?? '';

    return Scaffold(
      backgroundColor: _background,
      body: CustomScrollView(
        slivers: [
          // ── App bar with status gradient ─────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: fault.isResolved ? _success : _crimson,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (!fault.isResolved)
                IconButton(
                  tooltip: 'Asansöre Git',
                  icon: const Icon(Icons.elevator_outlined,
                      color: Colors.white),
                  onPressed: () =>
                      context.push('/elevator/${fault.elevatorId}'),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _StatusHeader(
                isResolved: fault.isResolved,
                reportedAt: fault.reportedAt,
                resolvedAt: fault.resolvedAt,
              ),
            ),
            title: const Text(
              'Arıza Detayı',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Elevator info card ────────────────────────────────
                  _InfoCard(
                    child: elevatorAsync.when(
                      loading: () => const _SkeletonRow(),
                      error: (e, st) => const _ElevatorErrorRow(),
                      data: (elevator) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                            icon: Icons.elevator_outlined,
                            label: 'Asansör',
                          ),
                          const SizedBox(height: 10),
                          Text(
                            elevator.buildingName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _onSurface,
                            ),
                          ),
                          if (elevatorAddress.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 14, color: _outline),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    elevatorAddress,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          _StatusBadge(isResolved: fault.isResolved),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Fault description ─────────────────────────────────
                  _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(
                          icon: Icons.report_problem_outlined,
                          label: 'Arıza Açıklaması',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          fault.description.isNotEmpty
                              ? fault.description
                              : 'Açıklama girilmedi.',
                          style: const TextStyle(
                            fontSize: 15,
                            color: _onSurface,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Photo ─────────────────────────────────────────────
                  if (fault.photoUrl != null &&
                      fault.photoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _PhotoCard(photoUrl: fault.photoUrl!),
                  ],

                  // ── Resolution notes (if resolved) ────────────────────
                  if (fault.isResolved &&
                      fault.resolutionNotes != null &&
                      fault.resolutionNotes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoCard(
                      accentColor: _success,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                            icon: Icons.check_circle_outline,
                            label: 'Çözüm Notu',
                            color: _success,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            fault.resolutionNotes!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: _onSurface,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Timestamps row ────────────────────────────────────
                  const SizedBox(height: 12),
                  _InfoCard(
                    child: Column(
                      children: [
                        _TimeRow(
                          icon: Icons.access_time_rounded,
                          label: 'Bildirim Tarihi',
                          time: fault.reportedAt,
                        ),
                        if (fault.isResolved &&
                            fault.resolvedAt != null) ...[
                          const Divider(height: 20, color: _outlineVariant),
                          _TimeRow(
                            icon: Icons.check_circle_outline,
                            label: 'Onarım Tarihi',
                            time: fault.resolvedAt!,
                            color: _success,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Action area ───────────────────────────────────────
                  const SizedBox(height: 20),
                  if (!fault.isResolved) ...[
                    // Notes toggle
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _notesExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: OutlinedButton.icon(
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('Çözüm notu ekle (isteğe bağlı)'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: const BorderSide(color: _outlineVariant),
                          foregroundColor: _onSurfaceVariant,
                        ),
                        onPressed: () =>
                            setState(() => _notesExpanded = true),
                      ),
                      secondChild: TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Çözüm Notu',
                          hintText:
                              'Yapılan işlemleri kısaca açıklayın…',
                          alignLabelWithHint: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _notesController.clear();
                              setState(() => _notesExpanded = false);
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Resolve button
                    FilledButton.icon(
                      icon: updateState.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        updateState.isLoading
                            ? 'Kaydediliyor…'
                            : 'Arızayı Onar',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: _success,
                      ),
                      onPressed: updateState.isLoading
                          ? null
                          : () => _handleResolve(context, ref, fault.id),
                    ),
                    const SizedBox(height: 8),

                    // Navigate to elevator
                    OutlinedButton.icon(
                      icon: const Icon(Icons.elevator_outlined),
                      label: Text('$elevatorName Detayına Git'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: _outlineVariant),
                        foregroundColor: _onSurface,
                      ),
                      onPressed: () =>
                          context.push('/elevator/${fault.elevatorId}'),
                    ),
                  ] else ...[
                    // Reopen button
                    OutlinedButton.icon(
                      icon: updateState.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        updateState.isLoading ? 'İşleniyor…' : 'Arızayı Yeniden Aç',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: BorderSide(
                          color: updateState.isLoading
                              ? _outlineVariant
                              : _crimson,
                        ),
                        foregroundColor: _crimson,
                      ),
                      onPressed: updateState.isLoading
                          ? null
                          : () => _handleReopen(context, ref, fault.id),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.elevator_outlined),
                      label: Text('$elevatorName Detayına Git'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: _outlineVariant),
                        foregroundColor: _onSurface,
                      ),
                      onPressed: () =>
                          context.push('/elevator/${fault.elevatorId}'),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleResolve(
    BuildContext context,
    WidgetRef ref,
    String faultId,
  ) async {
    final notes = _notesController.text.trim();
    final ctrl = ref.read(faultUpdateControllerProvider.notifier);
    final ok = await ctrl.resolve(faultId, resolutionNotes: notes.isEmpty ? null : notes);

    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Arıza başarıyla onarıldı olarak işaretlendi.'),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Refresh the fault data so the page re-renders to resolved state.
      ref.invalidate(faultByIdProvider(faultId));
    } else {
      final err = ref.read(faultUpdateControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $err'),
          backgroundColor: _crimson,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleReopen(
    BuildContext context,
    WidgetRef ref,
    String faultId,
  ) async {
    final ctrl = ref.read(faultUpdateControllerProvider.notifier);
    final ok = await ctrl.reopen(faultId);

    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arıza yeniden açıldı.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(faultByIdProvider(faultId));
    } else {
      final err = ref.read(faultUpdateControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $err'),
          backgroundColor: _crimson,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.isResolved,
    required this.reportedAt,
    this.resolvedAt,
  });

  final bool isResolved;
  final DateTime reportedAt;
  final DateTime? resolvedAt;

  @override
  Widget build(BuildContext context) {
    final gradient = isResolved
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF15803D), Color(0xFF16A34A)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
          );

    final icon =
        isResolved ? Icons.check_circle_rounded : Icons.warning_rounded;
    final label = isResolved ? 'ÇÖZÜLDÜ' : 'AÇIK ARIZA';
    final sub = isResolved
        ? 'Onarıldı: ${_fmt(resolvedAt ?? reportedAt)}'
        : 'Bildirildi: ${_fmt(reportedAt)}';

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    return DateFormat('d MMM y – HH:mm', 'tr_TR').format(local);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child, this.accentColor});

  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor != null
              ? accentColor!.withValues(alpha: 0.3)
              : _outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        photoUrl,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 220,
            color: _surfaceContainer,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          decoration: BoxDecoration(
            color: _surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 40, color: _outline),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? _onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isResolved});

  final bool isResolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isResolved ? _successContainer : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isResolved
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: 13,
            color: isResolved ? _success : _crimsonLight,
          ),
          const SizedBox(width: 5),
          Text(
            isResolved ? 'Çözüldü' : 'Açık',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isResolved ? _success : _crimsonDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.time,
    this.color,
  });

  final IconData icon;
  final String label;
  final DateTime time;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? _onSurfaceVariant;
    final local = time.toLocal();
    final formatted =
        DateFormat('d MMMM y, HH:mm', 'tr_TR').format(local);
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: _outline,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                formatted,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 14, width: 80, color: _outlineVariant),
        const SizedBox(height: 8),
        Container(height: 20, width: 180, color: _outlineVariant),
      ],
    );
  }
}

class _ElevatorErrorRow extends StatelessWidget {
  const _ElevatorErrorRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: _outline),
        SizedBox(width: 6),
        Text(
          'Asansör bilgisi yüklenemedi',
          style: TextStyle(color: _outline),
        ),
      ],
    );
  }
}

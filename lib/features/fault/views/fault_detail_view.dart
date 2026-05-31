import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../elevator/providers/elevator_providers.dart';

import '../models/fault_report_model.dart';

import '../providers/fault_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/info_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/section_label.dart';
import '../../../core/constants/app_durations.dart';
import 'package:confetti/confetti.dart';
// ── Local colour tokens (matches global theme) ──────────────────────────────

class FaultDetailView extends ConsumerWidget {
  const FaultDetailView({super.key, required this.faultId});

  final String faultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faultAsync = ref.watch(faultByIdProvider(faultId));

    return faultAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppThemeColors.of(context).background,
        appBar: AppBar(
          backgroundColor: AppThemeColors.of(context).background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Arıza Detayı',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: AppColors.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          centerTitle: false,
        ),
        body: const Padding(
          padding: EdgeInsets.all(16.0),
          child: LoadingState(isList: false),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppThemeColors.of(context).background,
        appBar: AppBar(
          backgroundColor: AppThemeColors.of(context).background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Arıza Detayı',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: AppColors.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          centerTitle: false,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Arıza yüklenemedi',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                e.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => ref.invalidate(faultByIdProvider(faultId)),
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
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _confettiController.dispose();
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
      backgroundColor: AppThemeColors.of(context).background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── App bar with status gradient ─────────────────────────────
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: fault.isResolved
                    ? AppColors.success
                    : AppColors.primary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  if (!fault.isResolved)
                    IconButton(
                      tooltip: 'Asansöre Git',
                      icon: const Icon(
                        Icons.elevator_outlined,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          context.push('/elevator/${fault.elevatorId}'),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _StatusHeader(
                    isResolved: fault.isResolved,
                    reportedAt: fault.reportedAt,
                    resolvedAt: fault.resolvedAt,
                    onLongPress: fault.isResolved
                        ? null
                        : () => _showResolveDialog(context, fault.id),
                  ),
                ),
                title: const Text(
                  'Arıza Detayı',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Elevator info card ────────────────────────────────
                      InfoCard(
                        child: elevatorAsync.when(
                          loading: () => const _SkeletonRow(),
                          error: (e, st) => const _ElevatorErrorRow(),
                          data: (elevator) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel(
                                icon: Icons.elevator_outlined,
                                label: 'Asansör',
                                uppercase: true,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                elevator.buildingName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              if (elevatorAddress.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: AppColors.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        elevatorAddress,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.onSurfaceVariant,
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
                      InfoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel(
                              icon: Icons.report_problem_outlined,
                              label: 'Arıza Açıklaması',
                              uppercase: true,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              fault.description.isNotEmpty
                                  ? fault.description
                                  : 'Açıklama girilmedi.',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.onSurface,
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
                        InfoCard(
                          accentColor: AppColors.success,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel(
                                icon: Icons.check_circle_outline,
                                label: 'Çözüm Notu',
                                color: AppColors.success,
                                uppercase: true,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                fault.resolutionNotes!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.onSurface,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Timestamps row ────────────────────────────────────
                      const SizedBox(height: 12),
                      InfoCard(
                        child: Column(
                          children: [
                            _TimeRow(
                              icon: Icons.access_time_rounded,
                              label: 'Bildirim Tarihi',
                              time: fault.reportedAt,
                            ),
                            if (fault.isResolved &&
                                fault.resolvedAt != null) ...[
                              const Divider(
                                height: 20,
                                color: AppColors.outlineVariant,
                              ),
                              _TimeRow(
                                icon: Icons.check_circle_outline,
                                label: 'Onarım Tarihi',
                                time: fault.resolvedAt!,
                                color: AppColors.success,
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
                              side: const BorderSide(
                                color: AppColors.outlineVariant,
                              ),
                              foregroundColor: AppColors.onSurfaceVariant,
                            ),
                            onPressed: () =>
                                setState(() => _notesExpanded = true),
                          ),
                          secondChild: TextField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Çözüm Notu',
                              hintText: 'Yapılan işlemleri kısaca açıklayın…',
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
                            backgroundColor: AppColors.success,
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
                            side: const BorderSide(
                              color: AppColors.outlineVariant,
                            ),
                            foregroundColor: AppColors.onSurface,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(
                            updateState.isLoading
                                ? 'İşleniyor…'
                                : 'Arızayı Yeniden Aç',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: BorderSide(
                              color: updateState.isLoading
                                  ? AppColors.outlineVariant
                                  : AppColors.primary,
                            ),
                            foregroundColor: AppColors.primary,
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
                            side: const BorderSide(
                              color: AppColors.outlineVariant,
                            ),
                            foregroundColor: AppColors.onSurface,
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
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 8,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showResolveDialog(BuildContext context, String faultId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arızayı Onar'),
        content: const Text(
          'Bu arızayı onarıldı olarak işaretlemek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleResolve(context, ref, faultId);
            },
            child: const Text('Evet, Onar'),
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
    final ok = await ctrl.resolve(
      faultId,
      resolutionNotes: notes.isEmpty ? null : notes,
    );

    if (ok) {
      _confettiController.play();
      await HapticFeedback.lightImpact();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Arıza başarıyla onarıldı olarak işaretlendi.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: AppDurations.snackBarSuccess,
        ),
      );
      // Refresh the fault data so the page re-renders to resolved state.
      ref.invalidate(faultByIdProvider(faultId));
    } else {
      await HapticFeedback.heavyImpact();
      if (!context.mounted) return;
      final err = ref.read(faultUpdateControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $err'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: AppDurations.snackBarError,
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

    if (ok) {
      await HapticFeedback.lightImpact();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arıza yeniden açıldı.'),
          behavior: SnackBarBehavior.floating,
          duration: AppDurations.snackBarSuccess,
        ),
      );
      ref.invalidate(faultByIdProvider(faultId));
    } else {
      await HapticFeedback.heavyImpact();
      if (!context.mounted) return;
      final err = ref.read(faultUpdateControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $err'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: AppDurations.snackBarError,
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
    this.onLongPress,
  });

  final bool isResolved;
  final DateTime reportedAt;
  final DateTime? resolvedAt;
  final VoidCallback? onLongPress;

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

    final icon = isResolved
        ? Icons.check_circle_rounded
        : Icons.warning_rounded;
    final label = isResolved ? 'ÇÖZÜLDÜ' : 'AÇIK ARIZA';
    final sub = isResolved
        ? 'Onarıldı: ${_fmt(resolvedAt ?? reportedAt)}'
        : 'Bildirildi: ${_fmt(reportedAt)}';

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.elasticOut,
                    );
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: curved, child: child),
                    );
                  },
                  child: Container(
                    key: ValueKey<bool>(isResolved),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 36),
                  ),
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
                if (!isResolved) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Onarmak için basılı tutun',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
            color: AppColors.surfaceContainer,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: AppColors.outline,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isResolved});

  final bool isResolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isResolved
            ? AppColors.successContainer
            : const Color(0xFFFEE2E2),
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
            color: isResolved ? AppColors.success : AppColors.secondary,
          ),
          const SizedBox(width: 5),
          Text(
            isResolved ? 'Çözüldü' : 'Açık',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isResolved ? AppColors.success : AppColors.primaryDark,
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
    final c = color ?? AppColors.onSurfaceVariant;
    final local = time.toLocal();
    final formatted = DateFormat('d MMMM y, HH:mm', 'tr_TR').format(local);
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
                  color: AppColors.outline,
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
        Container(height: 14, width: 80, color: AppColors.outlineVariant),
        const SizedBox(height: 8),
        Container(height: 20, width: 180, color: AppColors.outlineVariant),
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
        Icon(Icons.error_outline, size: 16, color: AppColors.outline),
        SizedBox(width: 6),
        Text(
          'Asansör bilgisi yüklenemedi',
          style: TextStyle(color: AppColors.outline),
        ),
      ],
    );
  }
}

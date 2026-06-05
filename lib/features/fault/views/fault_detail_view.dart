import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import 'package:asansor/features/elevator/providers/elevator_providers.dart';

import 'package:asansor/features/fault/models/fault_report_model.dart';

import 'package:asansor/features/fault/providers/fault_providers.dart';

import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/info_card.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/core/widgets/app_section_header.dart';
import 'package:asansor/core/constants/app_durations.dart';
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
            icon: Icon(
              Icons.arrow_back,
              color: AppThemeColors.of(context).primary,
            ),
            tooltip: 'Geri',
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Arıza Detayı',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppThemeColors.of(context).onSurface,
              letterSpacing: -0.2,
            ),
          ),
          centerTitle: false,
        ),
        body: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
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
            icon: Icon(
              Icons.arrow_back,
              color: AppThemeColors.of(context).primary,
            ),
            tooltip: 'Geri',
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Arıza Detayı',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppThemeColors.of(context).onSurface,
              letterSpacing: -0.2,
            ),
          ),
          centerTitle: false,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppThemeColors.of(context).primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Arıza yüklenemedi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppThemeColors.of(context).onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                e.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppThemeColors.of(context).onSurfaceVariant,
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

    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final baseHeight = (screenHeight * 0.22).clamp(180.0, 240.0);
    final expandedHeight = (baseHeight * textScale).clamp(180.0, 320.0);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── App bar with status gradient ─────────────────────────────
              SliverAppBar(
                expandedHeight: expandedHeight,
                pinned: true,
                backgroundColor: fault.isResolved
                    ? colors.success
                    : colors.primary,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: colors.onPrimary),
                  tooltip: 'Geri',
                  onPressed: () => context.pop(),
                ),
                actions: [
                  if (!fault.isResolved)
                    IconButton(
                      tooltip: 'Asansöre Git',
                      icon: Icon(
                        Icons.elevator_outlined,
                        color: colors.onPrimary,
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
                  ),
                ),
                title: Text(
                  'Arıza Detayı',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
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
                              const AppSectionHeader(
                                icon: Icons.elevator_outlined,
                                title: 'ASANSÖR',
                              ),
                              const SizedBox(height: 10),
                              Text(
                                elevator.buildingName,
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                              ),
                              if (elevatorAddress.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: colors.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        elevatorAddress,
                                        style: textTheme.labelLarge?.copyWith(
                                          color: colors.onSurfaceVariant,
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
                            const AppSectionHeader(
                              icon: Icons.report_problem_outlined,
                              title: 'ARIZA AÇIKLAMASI',
                            ),
                            const SizedBox(height: 10),
                            Text(
                              fault.description.isNotEmpty
                                  ? fault.description
                                  : 'Açıklama girilmedi.',
                              style: textTheme.bodyLarge?.copyWith(
                                color: colors.onSurface,
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
                          accentColor: colors.success,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppSectionHeader(
                                icon: Icons.check_circle_outline,
                                title: 'ÇÖZÜM NOTU',
                              ),
                              const SizedBox(height: 10),
                              Text(
                                fault.resolutionNotes!,
                                style: textTheme.bodyLarge?.copyWith(
                                  color: colors.onSurface,
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
                              Divider(height: 20, color: colors.outlineVariant),
                              _TimeRow(
                                icon: Icons.check_circle_outline,
                                label: 'Onarım Tarihi',
                                time: fault.resolvedAt!,
                                color: colors.success,
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
                              side: BorderSide(color: colors.outlineVariant),
                              foregroundColor: colors.onSurfaceVariant,
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
                                tooltip: 'Temizle ve Kapat',
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
                            backgroundColor: colors.success,
                          ),
                          onPressed: updateState.isLoading
                              ? null
                              : () => _showResolveDialog(context, fault.id),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Navigate to elevator
                        OutlinedButton.icon(
                          icon: const Icon(Icons.elevator_outlined),
                          label: Text('$elevatorName Detayına Git'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: BorderSide(color: colors.outlineVariant),
                            foregroundColor: colors.onSurface,
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
                                  ? colors.outlineVariant
                                  : colors.primary,
                            ),
                            foregroundColor: colors.primary,
                          ),
                          onPressed: updateState.isLoading
                              ? null
                              : () => _handleReopen(context, ref, fault.id),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.elevator_outlined),
                          label: Text('$elevatorName Detayına Git'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: BorderSide(color: colors.outlineVariant),
                            foregroundColor: colors.onSurface,
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
              colors: [
                AppThemeColors.of(context).success,
                AppThemeColors.of(context).primary,
                AppThemeColors.of(context).error,
                AppThemeColors.of(context).warning,
                AppThemeColors.of(context).navy,
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
          backgroundColor: AppThemeColors.of(context).success,
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
          backgroundColor: AppThemeColors.of(context).error,
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
          backgroundColor: AppThemeColors.of(context).error,
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
  });

  final bool isResolved;
  final DateTime reportedAt;
  final DateTime? resolvedAt;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final gradient = isResolved
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.success, colors.success.withValues(alpha: 0.8)],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.error, colors.error.withValues(alpha: 0.8)],
          );

    final icon = isResolved
        ? Icons.check_circle_rounded
        : Icons.warning_rounded;
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
              const SizedBox(height: 12),
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
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.onPrimary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: colors.onPrimary, size: 36),
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Column(
                  key: ValueKey<bool>(isResolved),
                  children: [
                    Text(
                      label,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sub,
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.85),
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
    final colors = AppThemeColors.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final photoHeight = (screenHeight * 0.25).clamp(200.0, 300.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        photoUrl,
        width: double.infinity,
        height: photoHeight,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: photoHeight,
            color: colors.surfaceContainer,
            child: const LoadingState(),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: colors.outline,
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
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isResolved ? colors.successContainer : colors.errorContainer,
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
            color: isResolved ? colors.success : colors.error,
          ),
          const SizedBox(width: 5),
          Text(
            isResolved ? 'Çözüldü' : 'Açık',
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isResolved ? colors.success : colors.error,
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
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final c = color ?? colors.onSurfaceVariant;
    final local = time.toLocal();
    final formatted = DateFormat('d MMMM y, HH:mm', 'tr_TR').format(local);
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.outline,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                formatted,
                style: textTheme.bodyMedium?.copyWith(
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
    final colors = AppThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 14, width: 80, color: colors.outlineVariant),
        const SizedBox(height: AppSpacing.sm),
        Container(height: 20, width: 180, color: colors.outlineVariant),
      ],
    );
  }
}

class _ElevatorErrorRow extends StatelessWidget {
  const _ElevatorErrorRow();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: colors.outline),
        const SizedBox(width: 6),
        Text(
          'Asansör bilgisi yüklenemedi',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.outline),
        ),
      ],
    );
  }
}

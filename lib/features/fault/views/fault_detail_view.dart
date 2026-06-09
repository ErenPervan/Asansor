import 'package:asansor/core/constants/app_durations.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:asansor/features/fault/providers/fault_providers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asansor/features/fault/widgets/fault_detail/elevator_side_panel.dart';
import 'package:asansor/features/fault/widgets/fault_detail/fault_action_bar.dart';
import 'package:asansor/features/fault/widgets/fault_detail/fault_title_block.dart';
import 'package:asansor/features/fault/widgets/fault_detail/main_fault_column.dart';

class FaultDetailView extends ConsumerWidget {
  const FaultDetailView({super.key, required this.faultId});

  final String faultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faultAsync = ref.watch(faultByIdProvider(faultId));

    return faultAsync.when(
      loading: () => _FaultShell(
        title: 'Arıza Detayı',
        child: const LoadingState(isList: false),
      ),
      error: (e, _) => _FaultShell(
        title: 'Arıza Detayı',
        child: _FaultLoadError(
          error: e.toString(),
          onRetry: () => ref.invalidate(faultByIdProvider(faultId)),
        ),
      ),
      data: (fault) => _FaultDetailScaffold(fault: fault),
    );
  }
}

class _FaultDetailScaffold extends ConsumerStatefulWidget {
  const _FaultDetailScaffold({required this.fault});

  final FaultReportModel fault;

  @override
  ConsumerState<_FaultDetailScaffold> createState() =>
      _FaultDetailScaffoldState();
}

class _FaultDetailScaffoldState extends ConsumerState<_FaultDetailScaffold> {
  final _notesController = TextEditingController();
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _notesController.text = widget.fault.resolutionNotes ?? '';
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
    final colors = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurfaceVariant),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Asansor',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Center(
              child: Text(
                'Operasyon',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FaultTitleBlock(fault: fault),
                          const SizedBox(height: AppSpacing.lg),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 880;
                              final main = MainFaultColumn(
                                fault: fault,
                                notesController: _notesController,
                              );
                              final side = ElevatorSidePanel(
                                fault: fault,
                                elevatorAsync: elevatorAsync,
                              );

                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 2, child: main),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(child: side),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  main,
                                  const SizedBox(height: AppSpacing.md),
                                  side,
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              FaultActionBar(
                fault: fault,
                isLoading: updateState.isLoading,
                onResolve: () => _showResolveDialog(context, fault.id),
                onReopen: () => _handleReopen(context, ref, fault.id),
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
                colors.success,
                colors.primary,
                colors.error,
                colors.warning,
                AppColors.accentGold,
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

class _FaultShell extends StatelessWidget {
  const _FaultShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurfaceVariant),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

class _FaultLoadError extends StatelessWidget {
  const _FaultLoadError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded, size: 52, color: colors.error),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Arıza yüklenemedi',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          error,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
      ],
    );
  }
}

import 'package:asansor/core/constants/app_durations.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:asansor/features/fault/providers/fault_providers.dart';
import 'package:asansor/features/fault/views/widgets/fault_action_bar.dart';
import 'package:asansor/features/fault/views/widgets/fault_dates_grid.dart';
import 'package:asansor/features/fault/views/widgets/fault_photo_panel.dart';
import 'package:asansor/features/fault/views/widgets/fault_premium_panel.dart';
import 'package:asansor/features/fault/views/widgets/fault_shell.dart';
import 'package:asansor/features/fault/views/widgets/fault_side_panel.dart';
import 'package:asansor/features/fault/views/widgets/fault_title_block.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asansor/l10n/app_localizations.dart';

class FaultDetailView extends ConsumerWidget {
  const FaultDetailView({super.key, required this.faultId});

  final String faultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faultAsync = ref.watch(faultByIdProvider(faultId));

    return faultAsync.when(
      loading: () => const FaultShell(
        title: 'Arıza Detayı',
        child: LoadingState(isList: false),
      ),
      error: (e, _) => FaultShell(
        title: 'Arıza Detayı',
        child: FaultLoadError(
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
                              final main = _MainFaultColumn(
                                fault: fault,
                                notesController: _notesController,
                              );
                              final side = FaultSidePanel(
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
        title: Text(AppLocalizations.of(ctx)!.faultDetailResolveButton),
        content: const Text(
          'Bu arızayı onarıldı olarak işaretlemek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.generalCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleResolve(context, ref, faultId);
            },
            child: Text(
              AppLocalizations.of(ctx)!.faultDetailConfirmResolveButton,
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
          content: Text(
            AppLocalizations.of(context)!.faultDetailResolveSuccess,
          ),
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
          content: Text(
            AppLocalizations.of(context)!.generalError(err.toString()),
          ),
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
        SnackBar(
          content: Text(AppLocalizations.of(context)!.faultDetailReopenSuccess),
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
          content: Text(
            AppLocalizations.of(context)!.generalError(err.toString()),
          ),
          backgroundColor: AppThemeColors.of(context).error,
          behavior: SnackBarBehavior.floating,
          duration: AppDurations.snackBarError,
        ),
      );
    }
  }
}

class _MainFaultColumn extends StatelessWidget {
  const _MainFaultColumn({required this.fault, required this.notesController});

  final FaultReportModel fault;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Column(
      children: [
        FaultPremiumPanel(
          accentColor: fault.isResolved ? colors.success : colors.error,
          title: 'Arıza Açıklaması',
          icon: Icons.report_problem_outlined,
          iconColor: fault.isResolved ? colors.success : colors.error,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.32),
                  ),
                ),
                child: Text(
                  fault.description.isNotEmpty
                      ? fault.description
                      : 'Açıklama girilmedi.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurface,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FaultDatesGrid(fault: fault),
            ],
          ),
        ),
        if (fault.photoUrl?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.md),
          FaultPhotoPanel(photoUrl: fault.photoUrl!),
        ],
        const SizedBox(height: AppSpacing.md),
        FaultPremiumPanel(
          title: 'Çözüm Notu',
          icon: Icons.edit_note_rounded,
          iconColor: colors.primaryDark,
          child: fault.isResolved
              ? Text(
                  fault.resolutionNotes?.isNotEmpty == true
                      ? fault.resolutionNotes!
                      : 'Çözüm notu girilmedi.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurface,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Müdahale detaylarını ve değiştirilen parçaları buraya giriniz.',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: notesController,
                      minLines: 5,
                      maxLines: 7,
                      decoration: InputDecoration(
                        hintText:
                            'Örn: Kapı motoru kontrol edildi, sensör bağlantıları yenilendi...',
                        filled: true,
                        fillColor: colors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colors.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colors.primary.withValues(alpha: 0.42),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

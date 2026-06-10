import 'package:asansor/core/constants/app_durations.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import 'package:asansor/features/fault/providers/fault_providers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
                          _FaultTitleBlock(fault: fault),
                          const SizedBox(height: AppSpacing.lg),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 880;
                              final main = _MainFaultColumn(
                                fault: fault,
                                notesController: _notesController,
                              );
                              final side = _ElevatorSidePanel(
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
              _FaultActionBar(
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

class _FaultTitleBlock extends StatelessWidget {
  const _FaultTitleBlock({required this.fault});

  final FaultReportModel fault;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final critical = _isCritical(fault);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: fault.isResolved
                ? colors.successContainer
                : colors.errorContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: fault.isResolved
                  ? colors.success.withValues(alpha: 0.2)
                  : colors.error.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                fault.isResolved
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                size: 17,
                color: fault.isResolved ? colors.success : colors.error,
              ),
              const SizedBox(width: 7),
              Text(
                fault.isResolved
                    ? 'Çözülmüş Arıza Kaydı'
                    : critical
                    ? 'Kritik Arıza Bildirimi'
                    : 'Açık Arıza Bildirimi',
                style: textTheme.labelSmall?.copyWith(
                  color: fault.isResolved
                      ? colors.success
                      : colors.onErrorContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          fault.faultType?.isNotEmpty == true
              ? fault.faultType!
              : 'Arıza Detayı',
          style: textTheme.headlineSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(Icons.tag_rounded, size: 17, color: colors.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              'ARZ-${_shortId(fault.id)}',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
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
        _PremiumPanel(
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
              _FaultDatesGrid(fault: fault),
            ],
          ),
        ),
        if (fault.photoUrl?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.md),
          _PhotoPanel(photoUrl: fault.photoUrl!),
        ],
        const SizedBox(height: AppSpacing.md),
        _PremiumPanel(
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

class _FaultDatesGrid extends StatelessWidget {
  const _FaultDatesGrid({required this.fault});

  final FaultReportModel fault;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final reported = _DateBlock(
          label: 'Bildirim Tarihi',
          icon: Icons.calendar_today_outlined,
          value: _formatDate(fault.reportedAt),
          iconColor: colors.secondary,
        );
        final targetOrResolved = _DateBlock(
          label: fault.isResolved ? 'Onarım Tarihi' : 'Hedeflenen Onarım',
          icon: fault.isResolved
              ? Icons.check_circle_outline_rounded
              : Icons.schedule_rounded,
          value: fault.isResolved && fault.resolvedAt != null
              ? _formatDate(fault.resolvedAt!)
              : _formatDate(fault.reportedAt.add(const Duration(hours: 4))),
          iconColor: fault.isResolved ? colors.success : AppColors.accentGold,
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: reported),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: targetOrResolved),
            ],
          );
        }

        return Column(
          children: [
            reported,
            const SizedBox(height: AppSpacing.md),
            targetOrResolved,
          ],
        );
      },
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({
    required this.label,
    required this.icon,
    required this.value,
    required this.iconColor,
  });

  final String label;
  final IconData icon;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ElevatorSidePanel extends StatelessWidget {
  const _ElevatorSidePanel({required this.fault, required this.elevatorAsync});

  final FaultReportModel fault;
  final AsyncValue<ElevatorModel> elevatorAsync;

  @override
  Widget build(BuildContext context) {
    return _PremiumPanel(
      title: 'Asansör Bilgisi',
      icon: Icons.elevator_outlined,
      child: elevatorAsync.when(
        loading: () => const LoadingState(isList: false),
        error: (_, _) => const _ElevatorErrorContent(),
        data: (elevator) =>
            _ElevatorInfoContent(elevator: elevator, fault: fault),
      ),
    );
  }
}

class _ElevatorInfoContent extends StatelessWidget {
  const _ElevatorInfoContent({required this.elevator, required this.fault});

  final ElevatorModel elevator;
  final FaultReportModel fault;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLine(
          icon: Icons.location_on_outlined,
          label: 'Konum',
          value: elevator.address?.isNotEmpty == true
              ? elevator.address!
              : 'Adres belirtilmemiş',
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoLine(
          icon: Icons.precision_manufacturing_outlined,
          label: 'Model / Kapasite',
          value:
              [
                if (elevator.model?.isNotEmpty == true) elevator.model!,
                if (elevator.capacity != null) '${elevator.capacity} kg',
              ].isEmpty
              ? 'Belirtilmedi'
              : [
                  if (elevator.model?.isNotEmpty == true) elevator.model!,
                  if (elevator.capacity != null) '${elevator.capacity} kg',
                ].join(' / '),
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoLine(
          icon: Icons.build_circle_outlined,
          label: 'Durum',
          value: _elevatorStatusLabel(elevator),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.push('/elevator/${fault.elevatorId}'),
          icon: const Icon(Icons.info_outline_rounded),
          label: const Text('Asansör Detayına Git'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primaryDark,
            backgroundColor: colors.primaryFixed.withValues(alpha: 0.22),
            side: BorderSide(color: colors.primary.withValues(alpha: 0.16)),
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.secondary, size: 21),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoPanel extends StatelessWidget {
  const _PhotoPanel({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return _PremiumPanel(
      title: 'Görsel Kanıt',
      icon: Icons.image_outlined,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          photoUrl,
          width: double.infinity,
          height: 240,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 240,
              color: colors.surfaceContainer,
              child: const LoadingState(),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            height: 160,
            color: colors.surfaceContainer,
            alignment: Alignment.center,
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

class _FaultActionBar extends StatelessWidget {
  const _FaultActionBar({
    required this.fault,
    required this.isLoading,
    required this.onResolve,
    required this.onReopen,
  });

  final FaultReportModel fault;
  final bool isLoading;
  final VoidCallback onResolve;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.92),
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : fault.isResolved
                        ? onReopen
                        : () => context.pop(),
                    icon: Icon(
                      fault.isResolved
                          ? Icons.refresh_rounded
                          : Icons.arrow_back_rounded,
                    ),
                    label: Text(fault.isResolved ? 'Yeniden Aç' : 'Geri Dön'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: colors.onSurface,
                      side: BorderSide(color: colors.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (!fault.isResolved) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onResolve,
                      icon: isLoading
                          ? SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colors.onPrimary,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        isLoading ? 'Kaydediliyor...' : 'Onarıldı İşaretle',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        backgroundColor: colors.primaryDark,
                        foregroundColor: colors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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
}

class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel({
    required this.child,
    this.title,
    this.icon,
    this.iconColor,
    this.accentColor,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (accentColor != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accentColor),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      if (icon != null) ...[
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: (iconColor ?? colors.primaryDark).withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            color: iconColor ?? colors.primaryDark,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Text(
                          title!,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                child,
              ],
            ),
          ),
        ],
      ),
    );
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
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
      ],
    );
  }
}

class _ElevatorErrorContent extends StatelessWidget {
  const _ElevatorErrorContent();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: colors.outline),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Asansör bilgisi yüklenemedi',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

bool _isCritical(FaultReportModel fault) {
  final priority = fault.priority?.toLowerCase();
  return priority == 'high' || priority == 'emergency';
}

String _shortId(String id) {
  final cleaned = id.replaceAll('-', '');
  final short = cleaned.length < 8 ? cleaned : cleaned.substring(0, 8);
  return short.toUpperCase();
}

String _formatDate(DateTime date) {
  return DateFormat('d MMM y, HH:mm', 'tr_TR').format(date.toLocal());
}

String _elevatorStatusLabel(ElevatorModel elevator) {
  return switch (elevator.status.name) {
    'active' => 'Aktif',
    'faulty' => 'Arızalı',
    'underMaintenance' => 'Bakımda',
    'inactive' => 'Pasif',
    _ => elevator.status.name,
  };
}

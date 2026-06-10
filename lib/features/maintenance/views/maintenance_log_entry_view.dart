import 'dart:io';
import 'dart:math' as math;

import 'package:asansor/core/constants/app_durations.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/empty_state.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/admin/models/checklist_item_model.dart';
import 'package:asansor/features/admin/providers/checklist_provider.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/maintenance/providers/maintenance_providers.dart';
import 'package:asansor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceLogEntryView extends ConsumerStatefulWidget {
  const MaintenanceLogEntryView({super.key, required this.elevatorId});

  final String elevatorId;

  @override
  ConsumerState<MaintenanceLogEntryView> createState() =>
      _MaintenanceLogEntryViewState();
}

class _MaintenanceLogEntryViewState
    extends ConsumerState<MaintenanceLogEntryView>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  final Map<String, bool> _checkedItems = {};
  final List<String> _photoPaths = [];

  late final SignatureController _techSignatureController;
  late final SignatureController _custSignatureController;
  bool _controllersInitialized = false;

  late final AnimationController _signatureShakeController;
  bool _techSignatureError = false;
  bool _custSignatureError = false;

  @override
  void initState() {
    super.initState();
    _signatureShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllersInitialized) {
      final colors = AppThemeColors.of(context);
      _techSignatureController = SignatureController(
        penStrokeWidth: 2,
        penColor: colors.onSurface,
        exportBackgroundColor: Colors.transparent,
      );
      _custSignatureController = SignatureController(
        penStrokeWidth: 2,
        penColor: colors.onSurface,
        exportBackgroundColor: Colors.transparent,
      );
      _controllersInitialized = true;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _techSignatureController.dispose();
    _custSignatureController.dispose();
    _signatureShakeController.dispose();
    super.dispose();
  }

  Future<void> _addPhotoFromCamera() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo == null) return;

      final savedPath = await _persistPhoto(photo);
      if (savedPath == null || !mounted) return;

      setState(() => _photoPaths.add(savedPath));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf eklenemedi: $e'),
          duration: AppDurations.snackBarError,
        ),
      );
    }
  }

  Future<void> _addPhotosFromGallery() async {
    try {
      final photos = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (photos.isEmpty) return;

      final savedPaths = <String>[];
      for (final photo in photos) {
        final savedPath = await _persistPhoto(photo);
        if (savedPath != null) savedPaths.add(savedPath);
      }

      if (savedPaths.isEmpty || !mounted) return;

      setState(() => _photoPaths.addAll(savedPaths));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraflar eklenemedi: $e'),
          duration: AppDurations.snackBarError,
        ),
      );
    }
  }

  Future<String?> _persistPhoto(XFile photo) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${appDir.path}/maintenance_photos');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final extension = _safeExtension(
      photo.name.isNotEmpty ? photo.name : photo.path,
    );
    final fileName =
        'photo_${DateTime.now().millisecondsSinceEpoch}_${_photoPaths.length}.$extension';
    final savedFile = await File(
      photo.path,
    ).copy('${targetDir.path}/$fileName');

    return savedFile.path;
  }

  String _safeExtension(String nameOrPath) {
    final dotIndex = nameOrPath.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == nameOrPath.length - 1) {
      return 'jpg';
    }

    final extension = nameOrPath.substring(dotIndex + 1).toLowerCase();
    if (extension.length > 5) {
      return 'jpg';
    }

    return extension;
  }

  void _triggerSignatureError({
    required bool techMissing,
    required bool custMissing,
  }) {
    setState(() {
      _techSignatureError = techMissing;
      _custSignatureError = custMissing;
    });
    _signatureShakeController.forward(from: 0);
  }

  Future<String?> _saveSignature(
    SignatureController controller,
    String prefix,
  ) async {
    if (controller.isEmpty) return null;
    final bytes = await controller.toPngBytes();
    if (bytes == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${appDir.path}/maintenance_signatures');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${targetDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.maintenanceSessionError),
          duration: AppDurations.snackBarError,
        ),
      );
      return;
    }

    try {
      final techMissing = _techSignatureController.isEmpty;
      final custMissing = _custSignatureController.isEmpty;
      if (techMissing || custMissing) {
        await HapticFeedback.heavyImpact();
        if (!mounted) return;
        final colors = AppThemeColors.of(context);
        _triggerSignatureError(
          techMissing: techMissing,
          custMissing: custMissing,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.maintenanceSignatureError),
            backgroundColor: colors.error,
            duration: AppDurations.snackBarError,
          ),
        );
        return;
      }

      final techSigPath = await _saveSignature(
        _techSignatureController,
        'tech',
      );
      final custSigPath = await _saveSignature(
        _custSignatureController,
        'cust',
      );

      final photos = _photoPaths.isEmpty
          ? null
          : List<String>.from(_photoPaths);

      await ref
          .read(maintenanceControllerProvider.notifier)
          .addLog(
            elevatorId: widget.elevatorId,
            technicianId: userId,
            notes: _notesController.text.trim(),
            maintenanceDate: DateTime.now().toUtc(),
            checklist: _checkedItems,
            photos: photos,
            signaturePath: techSigPath,
            customerSignaturePath: custSigPath,
          );

      await HapticFeedback.lightImpact();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final colors = AppThemeColors.of(context);
          return TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: AlertDialog(
                  backgroundColor: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.xl),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: colors.success,
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.maintenanceSavedTitle,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                      ),
                    ],
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.surface,
                      ),
                      child: Text(l10n.maintenanceSavedConfirm),
                    ),
                  ],
                  actionsAlignment: MainAxisAlignment.center,
                ),
              );
            },
          );
        },
      );

      if (!mounted) return;
      context.go('/');
    } catch (e) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      final colors = AppThemeColors.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.maintenanceSaveError(e.toString())),
          backgroundColor: colors.error,
          duration: AppDurations.snackBarError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final maintenanceState = ref.watch(maintenanceControllerProvider);
    final elevatorAsync = ref.watch(elevatorByIdProvider(widget.elevatorId));
    final checklistAsync = ref.watch(checklistProvider);

    return PopScope(
      canPop: !maintenanceState.isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && maintenanceState.isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.maintenanceSavePrevention),
              backgroundColor: colors.error,
              duration: AppDurations.snackBarInfo,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface.withValues(alpha: 0.92),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: colors.onSurfaceVariant,
            ),
            tooltip: 'Geri',
            onPressed: maintenanceState.isLoading ? null : () => context.pop(),
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
                    color: colors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: elevatorAsync.when(
          data: (elevator) => Form(
            key: _formKey,
            child: Column(
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
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _FormHero(elevator: elevator),
                            const SizedBox(height: AppSpacing.lg),
                            _ChecklistProgressCard(
                              checkedItems: _checkedItems,
                              checklistAsync: checklistAsync,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _ChecklistPanel(
                              checklistAsync: checklistAsync,
                              checkedItems: _checkedItems,
                              onToggle: (id, value) {
                                setState(() => _checkedItems[id] = value);
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _PhotoEvidencePanel(
                              photoPaths: _photoPaths,
                              onCamera: _addPhotoFromCamera,
                              onGallery: _addPhotosFromGallery,
                              onRemove: (index) {
                                setState(() => _photoPaths.removeAt(index));
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _NotesPanel(controller: _notesController),
                            const SizedBox(height: AppSpacing.lg),
                            _SignaturesPanel(
                              techSignatureController: _techSignatureController,
                              custSignatureController: _custSignatureController,
                              techSignatureError: _techSignatureError,
                              custSignatureError: _custSignatureError,
                              signatureShakeController:
                                  _signatureShakeController,
                              onTechClear: () =>
                                  _techSignatureController.clear(),
                              onCustClear: () =>
                                  _custSignatureController.clear(),
                              onTechInteract: () {
                                if (_techSignatureError) {
                                  setState(() => _techSignatureError = false);
                                }
                              },
                              onCustInteract: () {
                                if (_custSignatureError) {
                                  setState(() => _custSignatureError = false);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _SubmitBar(
                  isLoading: maintenanceState.isLoading,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
          loading: () => const LoadingState(),
          error: (err, stack) => ErrorState(
            message: l10n.generalError(err.toString()),
            onRetry: () =>
                ref.invalidate(elevatorByIdProvider(widget.elevatorId)),
          ),
        ),
      ),
    );
  }
}

class _FormHero extends StatelessWidget {
  const _FormHero({required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: colors.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                elevator.address?.isNotEmpty == true
                    ? elevator.address!
                    : elevator.buildingName,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Aylık Periyodik Bakım Formu',
          style: textTheme.headlineSmall?.copyWith(
            color: colors.primaryDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatusChip(
              label: 'Devam Ediyor',
              color: colors.warning,
              backgroundColor: colors.surfaceContainerHigh,
            ),
            Text(
              'Kayıt No: MNT-${DateTime.now().year}-${elevator.id.substring(0, elevator.id.length < 6 ? elevator.id.length : 6).toUpperCase()}',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChecklistProgressCard extends StatelessWidget {
  const _ChecklistProgressCard({
    required this.checkedItems,
    required this.checklistAsync,
  });

  final Map<String, bool> checkedItems;
  final AsyncValue<List<ChecklistItemModel>> checklistAsync;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final activeItems = checklistAsync.maybeWhen(
      data: (items) => items.where((item) => item.isActive).toList(),
      orElse: () => const <ChecklistItemModel>[],
    );
    final total = activeItems.length;
    final checked = activeItems
        .where((item) => checkedItems[item.id] == true)
        .length;
    final progress = total == 0 ? 0.0 : checked / total;

    return _PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Checklist İlerlemesi',
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: textTheme.titleLarge?.copyWith(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colors.surfaceContainer,
              color: AppColors.accentGold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$checked / $total kontrol tamamlandı',
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistPanel extends StatelessWidget {
  const _ChecklistPanel({
    required this.checklistAsync,
    required this.checkedItems,
    required this.onToggle,
  });

  final AsyncValue<List<ChecklistItemModel>> checklistAsync;
  final Map<String, bool> checkedItems;
  final void Function(String id, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return _PremiumPanel(
      title: l10n.maintenanceChecklistSection,
      icon: Icons.checklist_rounded,
      borderColor: colors.surfaceContainerHigh,
      child: checklistAsync.when(
        data: (items) {
          final activeItems = items.where((i) => i.isActive).toList();
          if (activeItems.isEmpty) {
            return EmptyState(
              icon: Icons.checklist_rtl_rounded,
              message: l10n.maintenanceChecklistEmpty,
            );
          }

          return Column(
            children: [
              for (final item in activeItems)
                _ChecklistRow(
                  item: item,
                  isChecked: checkedItems[item.id] == true,
                  onToggle: (value) => onToggle(item.id, value),
                ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LoadingState(),
        ),
        error: (err, stack) => ErrorState(
          message: l10n.maintenanceChecklistLoadError(err.toString()),
          onRetry: () {},
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.isChecked,
    required this.onToggle,
  });

  final ChecklistItemModel item;
  final bool isChecked;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => onToggle(!isChecked),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isChecked
              ? colors.primaryFixed.withValues(alpha: 0.34)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isChecked
                ? colors.primary.withValues(alpha: 0.16)
                : colors.outlineVariant.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isChecked,
              onChanged: (value) => onToggle(value ?? false),
              activeColor: colors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.description,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoEvidencePanel extends StatelessWidget {
  const _PhotoEvidencePanel({
    required this.photoPaths,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final List<String> photoPaths;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return _PremiumPanel(
      title: l10n.maintenancePhotosSection,
      icon: Icons.photo_library_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${photoPaths.length} Fotoğraf',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: Column(
        children: [
          if (photoPaths.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
              ),
              itemCount: photoPaths.length,
              itemBuilder: (context, index) {
                return _PhotoTile(
                  path: photoPaths[index],
                  onRemove: () => onRemove(index),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                l10n.maintenancePhotosEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: _EvidenceButton(
                  icon: Icons.photo_camera_outlined,
                  label: l10n.maintenancePhotosCamera,
                  onTap: onCamera,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _EvidenceButton(
                  icon: Icons.image_outlined,
                  label: l10n.maintenancePhotosGallery,
                  onTap: onGallery,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: colors.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: l10n.maintenancePhotosRemoveTooltip,
            style: IconButton.styleFrom(
              backgroundColor: colors.error.withValues(alpha: 0.9),
              foregroundColor: colors.onError,
              minimumSize: const Size(28, 28),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceButton extends StatelessWidget {
  const _EvidenceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primaryDark,
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
        backgroundColor: colors.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return _PremiumPanel(
      title: l10n.maintenanceNotesSection,
      icon: Icons.notes_outlined,
      child: TextFormField(
        controller: controller,
        minLines: 5,
        maxLines: 7,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: l10n.maintenanceNotesHint,
          filled: true,
          fillColor: colors.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
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
    );
  }
}

class _SignaturesPanel extends StatelessWidget {
  const _SignaturesPanel({
    required this.techSignatureController,
    required this.custSignatureController,
    required this.techSignatureError,
    required this.custSignatureError,
    required this.signatureShakeController,
    required this.onTechClear,
    required this.onCustClear,
    required this.onTechInteract,
    required this.onCustInteract,
  });

  final SignatureController techSignatureController;
  final SignatureController custSignatureController;
  final bool techSignatureError;
  final bool custSignatureError;
  final AnimationController signatureShakeController;
  final VoidCallback onTechClear;
  final VoidCallback onCustClear;
  final VoidCallback onTechInteract;
  final VoidCallback onCustInteract;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasError = techSignatureError || custSignatureError;

    return _PremiumPanel(
      title: l10n.maintenanceSignaturesSection,
      icon: Icons.draw_outlined,
      borderColor: hasError
          ? colors.errorContainer
          : colors.outlineVariant.withValues(alpha: 0.45),
      warning: hasError ? l10n.maintenanceSignatureError : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 620;
          final tech = _SignaturePad(
            label: l10n.maintenanceSignatureTechLabel,
            controller: techSignatureController,
            showError: techSignatureError,
            signatureShakeController: signatureShakeController,
            onClear: onTechClear,
            onInteract: onTechInteract,
          );
          final customer = _SignaturePad(
            label: l10n.maintenanceSignatureCustLabel,
            controller: custSignatureController,
            showError: custSignatureError,
            signatureShakeController: signatureShakeController,
            onClear: onCustClear,
            onInteract: onCustInteract,
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tech),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: customer),
              ],
            );
          }

          return Column(
            children: [
              tech,
              const SizedBox(height: AppSpacing.md),
              customer,
            ],
          );
        },
      ),
    );
  }
}

class _SignaturePad extends StatelessWidget {
  const _SignaturePad({
    required this.label,
    required this.controller,
    required this.showError,
    required this.signatureShakeController,
    required this.onClear,
    required this.onInteract,
  });

  final String label;
  final SignatureController controller;
  final bool showError;
  final AnimationController signatureShakeController;
  final VoidCallback onClear;
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: signatureShakeController,
      builder: (context, child) {
        final shake = showError
            ? math.sin(signatureShakeController.value * math.pi * 6) * 6
            : 0.0;
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: showError
                  ? colors.error.withValues(alpha: 0.05)
                  : colors.surfaceContainerLow,
              border: Border.all(
                color: showError
                    ? colors.error.withValues(alpha: 0.58)
                    : colors.outlineVariant,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Listener(
                  onPointerDown: (_) => onInteract(),
                  child: Signature(
                    controller: controller,
                    height: 150,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextButton(
                    onPressed: onClear,
                    child: Text(l10n.maintenanceSignatureClear),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.isLoading, required this.onSubmit});

  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;

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
            constraints: const BoxConstraints(maxWidth: 760),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  isLoading
                      ? l10n.maintenanceSavingMessage
                      : l10n.maintenanceSubmitButton,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primaryDark,
                  foregroundColor: colors.onPrimary,
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
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
    this.trailing,
    this.warning,
    this.borderColor,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final String? warning;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? colors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (warning != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              color: colors.errorContainer,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: colors.onErrorContainer,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      warning!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
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
                        Icon(icon, color: colors.primaryDark, size: 21),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Text(
                          title!,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Divider(color: colors.surfaceContainer),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppThemeColors.of(context).onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

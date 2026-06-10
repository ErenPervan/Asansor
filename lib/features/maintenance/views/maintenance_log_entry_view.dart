import 'dart:io';


import 'package:asansor/core/constants/app_durations.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/features/admin/providers/checklist_provider.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/maintenance/providers/maintenance_providers.dart';
import 'package:asansor/features/maintenance/views/widgets/maintenance_checklist_panel.dart';
import 'package:asansor/features/maintenance/views/widgets/maintenance_form_hero.dart';
import 'package:asansor/features/maintenance/views/widgets/maintenance_notes_panel.dart';
import 'package:asansor/features/maintenance/views/widgets/maintenance_photo_panel.dart';
import 'package:asansor/features/maintenance/views/widgets/maintenance_signatures_panel.dart';
import 'package:asansor/features/maintenance/views/widgets/maintenance_submit_bar.dart';
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

    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
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
                            MaintenanceFormHero(elevator: elevator),
                            const SizedBox(height: AppSpacing.lg),
                            MaintenanceChecklistProgressCard(
                              checkedItems: _checkedItems,
                              checklistAsync: checklistAsync,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            MaintenanceChecklistPanel(
                              checklistAsync: checklistAsync,
                              checkedItems: _checkedItems,
                              onToggle: (id, value) {
                                setState(() => _checkedItems[id] = value);
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            MaintenancePhotoEvidencePanel(
                              photoPaths: _photoPaths,
                              onCamera: _addPhotoFromCamera,
                              onGallery: _addPhotosFromGallery,
                              onRemove: (index) {
                                setState(() => _photoPaths.removeAt(index));
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            MaintenanceNotesPanel(controller: _notesController),
                            const SizedBox(height: AppSpacing.lg),
                            MaintenanceSignaturesPanel(
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
                MaintenanceSubmitBar(
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

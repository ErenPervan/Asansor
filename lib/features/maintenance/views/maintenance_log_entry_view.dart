import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../../admin/providers/checklist_provider.dart';
import '../providers/maintenance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/input_decorations.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_async_view.dart';
import '../../../core/widgets/app_form_field.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/constants/app_durations.dart';

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

  Future<void> _addPhotoFromCamera() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo == null) return;

      final savedPath = await _persistPhoto(photo);
      if (savedPath == null || !mounted) return;

      setState(() {
        _photoPaths.add(savedPath);
      });
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
        if (savedPath != null) {
          savedPaths.add(savedPath);
        }
      }

      if (savedPaths.isEmpty || !mounted) return;

      setState(() {
        _photoPaths.addAll(savedPaths);
      });
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

  @override
  void dispose() {
    _notesController.dispose();
    _techSignatureController.dispose();
    _custSignatureController.dispose();
    _signatureShakeController.dispose();
    super.dispose();
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

      // Premium Success Dialog
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

      // Navigate back to the home/dashboard
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
    final textTheme = Theme.of(context).textTheme;
    final sectionLabelStyle = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );
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
        appBar: AppBar(title: Text(l10n.maintenanceFormTitle)),
        body: elevatorAsync.when(
          data: (elevator) => Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Elevator Info Card
                Card(
                  elevation: 2,
                  color: colors.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          elevator.buildingName,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        if (elevator.address != null &&
                            elevator.address!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: colors.outline,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  elevator.address!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colors.outline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Checklist Section
                AppSectionHeader(
                  icon: Icons.checklist_rounded,
                  title: l10n.maintenanceChecklistSection,
                ),
                const SizedBox(height: AppSpacing.sm),

                checklistAsync.when(
                  data: (items) {
                    final activeItems = items.where((i) => i.isActive).toList();
                    if (activeItems.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: EmptyState(
                          icon: Icons.checklist_rtl_rounded,
                          message: l10n.maintenanceChecklistEmpty,
                        ),
                      );
                    }

                    final checkedCount = activeItems
                        .where((i) => _checkedItems[i.id] == true)
                        .length;
                    final totalCount = activeItems.length;
                    final progress = totalCount > 0
                        ? checkedCount / totalCount
                        : 0.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.maintenanceChecklistProgress(
                                  checkedCount,
                                  totalCount,
                                ),
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.outline,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: progress == 1.0
                                      ? colors.success
                                      : colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: colors.surfaceContainerHigh,
                            color: progress == 1.0
                                ? colors.success
                                : colors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: activeItems.map((item) {
                              final isChecked = _checkedItems[item.id] ?? false;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _checkedItems[item.id] = !isChecked;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Transform.scale(
                                        scale: 1.2,
                                        child: Checkbox(
                                          value: isChecked,
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() {
                                                _checkedItems[item.id] = value;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(
                                              height: 6,
                                            ), // align with scaled checkbox center
                                            Text(
                                              item.label,
                                              style: textTheme.bodyLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                    color: colors.onSurface,
                                                  ),
                                            ),
                                            if (item
                                                .description
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                item.description,
                                                style: textTheme.bodyMedium
                                                    ?.copyWith(
                                                      color: colors.outline,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: LoadingState(),
                  ),
                  error: (err, stack) => Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: ErrorState(
                      message: l10n.maintenanceChecklistLoadError(
                        err.toString(),
                      ),
                      onRetry: () => ref.invalidate(checklistProvider),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Photo Section
                AppSectionHeader(
                  icon: Icons.photo_library_outlined,
                  title: l10n.maintenancePhotosSection,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addPhotoFromCamera,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(l10n.maintenancePhotosCamera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addPhotosFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l10n.maintenancePhotosGallery),
                      ),
                    ),
                  ],
                ),
                if (_photoPaths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_photoPaths.length, (index) {
                      final path = _photoPaths[index];
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(path),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  color: colors.outlineVariant,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: colors.onSurfaceVariant,
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: IconButton(
                              onPressed: () {
                                setState(() {
                                  _photoPaths.removeAt(index);
                                });
                              },
                              icon: const Icon(Icons.close, size: 16),
                              style: IconButton.styleFrom(
                                backgroundColor: colors.surface.withValues(
                                  alpha: 0.7,
                                ),
                                foregroundColor: colors.onSurface,
                                padding: const EdgeInsets.all(2),
                                minimumSize: const Size(24, 24),
                              ),
                              tooltip: l10n.maintenancePhotosRemoveTooltip,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.maintenancePhotosEmpty),
                ],

                const SizedBox(height: AppSpacing.lg),

                // Notes Section
                AppSectionHeader(
                  icon: Icons.notes_outlined,
                  title: l10n.maintenanceNotesSection,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppFormField(
                  controller: _notesController,
                  maxLines: 4,
                  label: '',
                  hint: l10n.maintenanceNotesHint,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Signature Section
                AppSectionHeader(
                  icon: Icons.draw_outlined,
                  title: l10n.maintenanceSignaturesSection,
                ),
                const SizedBox(height: AppSpacing.sm),

                _buildSignaturePad(
                  label: l10n.maintenanceSignatureTechLabel,
                  controller: _techSignatureController,
                  showError: _techSignatureError,
                  onClear: () => _techSignatureController.clear(),
                  onInteract: () {
                    if (_techSignatureError) {
                      setState(() => _techSignatureError = false);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                _buildSignaturePad(
                  label: l10n.maintenanceSignatureCustLabel,
                  controller: _custSignatureController,
                  showError: _custSignatureError,
                  onClear: () => _custSignatureController.clear(),
                  onInteract: () {
                    if (_custSignatureError) {
                      setState(() => _custSignatureError = false);
                    }
                  },
                ),

                const SizedBox(height: AppSpacing.xl),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: maintenanceState.isLoading ? null : _submit,
                    icon: maintenanceState.isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colors.surface,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      maintenanceState.isLoading
                          ? l10n.maintenanceSavingMessage
                          : l10n.maintenanceSubmitButton,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.surface,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.surface,
                    ),
                  ),
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

  Widget _buildSignaturePad({
    required String label,
    required SignatureController controller,
    required bool showError,
    required VoidCallback onClear,
    required VoidCallback onInteract,
  }) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final borderColor = showError ? colors.error : colors.outline;

    return AnimatedBuilder(
      animation: _signatureShakeController,
      builder: (context, child) {
        final shake = showError
            ? math.sin(_signatureShakeController.value * math.pi * 6) * 6
            : 0.0;
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                  child: Listener(
                    onPointerDown: (_) => onInteract(),
                    child: Signature(
                      controller: controller,
                      height: 150,
                      backgroundColor: colors.surfaceContainer,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onClear,
                      child: Text(l10n.maintenanceSignatureClear),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

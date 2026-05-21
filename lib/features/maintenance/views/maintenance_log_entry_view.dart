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

import '../../elevator/providers/elevator_providers.dart';
import '../../admin/providers/checklist_provider.dart';
import '../providers/maintenance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_label.dart';

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

  final _techSignatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: AppColors.onSurface,
    exportBackgroundColor: Colors.transparent,
  );

  final _custSignatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: AppColors.onSurface,
    exportBackgroundColor: Colors.transparent,
  );

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf eklenemedi: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraflar eklenemedi: $e')));
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

  void _triggerSignatureError({required bool techMissing, required bool custMissing}) {
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

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum bilgisi alınamadı.')),
      );
      return;
    }

    try {
      final techMissing = _techSignatureController.isEmpty;
      final custMissing = _custSignatureController.isEmpty;
      if (techMissing || custMissing) {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        _triggerSignatureError(
          techMissing: techMissing,
          custMissing: custMissing,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lütfen hem teknisyen hem de müşteri imzasını tamamlayın.',
            ),
            backgroundColor: AppColors.error,
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

      if (!mounted) return;

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bakım başarıyla kaydedildi.'),
          backgroundColor: AppColors.success,
        ),
      );

      // Navigate back to the home/dashboard
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayıt sırasında hata oluştu: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final elevatorAsync = ref.watch(elevatorByIdProvider(widget.elevatorId));
    final checklistAsync = ref.watch(checklistProvider);
    final maintenanceState = ref.watch(maintenanceControllerProvider);
    final sectionLabelStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return PopScope(
      canPop: !maintenanceState.isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && maintenanceState.isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lütfen kaydetme işlemi tamamlanana kadar bekleyin.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Yeni Bakım Formu')),
        body: elevatorAsync.when(
        data: (elevator) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Elevator Info Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        elevator.buildingName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (elevator.address != null &&
                          elevator.address!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: AppColors.outline,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                elevator.address!,
                                style: const TextStyle(color: AppColors.outline),
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
              SectionLabel(
                label: 'Kontrol Listesi',
                textStyle: sectionLabelStyle,
              ),
              const SizedBox(height: AppSpacing.sm),

              checklistAsync.when(
                data: (items) {
                  final activeItems = items.where((i) => i.isActive).toList();
                  if (activeItems.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: EmptyState(
                        icon: Icons.checklist_rtl_rounded,
                        message: 'Aktif kontrol öğesi bulunamadı.',
                      ),
                    );
                  }

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: activeItems.map((item) {
                        final isChecked = _checkedItems[item.id] ?? false;
                        return CheckboxListTile(
                          title: Text(item.label),
                          subtitle: item.description.isNotEmpty
                              ? Text(item.description)
                              : null,
                          value: isChecked,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _checkedItems[item.id] = value;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: LoadingState(),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ErrorState(
                    message: 'Kontrol listesi yüklenemedi: $err',
                    onRetry: () => ref.invalidate(checklistProvider),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Photo Section
              SectionLabel(
                label: 'Fotoğraflar',
                textStyle: sectionLabelStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addPhotoFromCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Kamera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addPhotosFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeri'),
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
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
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
                              backgroundColor: Colors.white70,
                              padding: const EdgeInsets.all(2),
                              minimumSize: const Size(24, 24),
                            ),
                            tooltip: 'Fotoğrafı kaldır',
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text('Henüz fotoğraf eklenmedi.'),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Notes Section
              SectionLabel(
                label: 'Bakım Notları',
                textStyle: sectionLabelStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Yapılan işlemleri, değiştirilen parçaları vb. buraya yazın...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Signature Section
              SectionLabel(
                label: 'İmzalar',
                textStyle: sectionLabelStyle,
              ),
              const SizedBox(height: AppSpacing.sm),

              _buildSignaturePad(
                label: 'Teknisyen İmzası',
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
                label: 'Müşteri İmzası',
                controller: _custSignatureController,
                showError: _custSignatureError,
                onClear: () => _custSignatureController.clear(),
                onInteract: () {
                  if (_custSignatureError) {
                    setState(() => _custSignatureError = false);
                  }
                },
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: maintenanceState.isLoading ? null : _submit,
                  icon: maintenanceState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    maintenanceState.isLoading
                        ? 'Kaydediliyor...'
                        : 'Bakımı Kaydet',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        loading: () => const LoadingState(),
        error: (err, stack) => ErrorState(
          message: 'Hata: $err',
          onRetry: () => ref.invalidate(elevatorByIdProvider(widget.elevatorId)),
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
    final borderColor = showError ? AppColors.error : AppColors.outline;

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
            style: const TextStyle(fontWeight: FontWeight.w500),
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
                      backgroundColor: AppColors.surfaceContainer,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onClear,
                      child: const Text('Temizle'),
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


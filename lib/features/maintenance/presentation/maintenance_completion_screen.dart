import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:signature/signature.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/maintenance_completion_controller.dart';

class MaintenanceCompletionScreen extends ConsumerStatefulWidget {
  final String scheduleId;
  final String elevatorId;
  final String elevatorLocation;

  const MaintenanceCompletionScreen({
    super.key,
    required this.scheduleId,
    required this.elevatorId,
    this.elevatorLocation = 'Belirtilmedi',
  });

  @override
  ConsumerState<MaintenanceCompletionScreen> createState() =>
      _MaintenanceCompletionScreenState();
}

class _MaintenanceCompletionScreenState
    extends ConsumerState<MaintenanceCompletionScreen> {
  // Technician signature (step 2)
  final SignatureController _techSignatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  // Customer / building-rep signature (step 3)
  final SignatureController _custSignatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final TextEditingController _notesController = TextEditingController();

  // Steps: 0-Checklist, 1-Photos, 2-Tech Sig, 3-Customer Sig, 4-Summary
  static const int _totalSteps = 5;

  @override
  void dispose() {
    _techSignatureController.dispose();
    _custSignatureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      ref
          .read(maintenanceCompletionControllerProvider.notifier)
          .addPhoto(File(pickedFile.path));
    }
  }

  Future<void> _saveTechSignature() async {
    if (_techSignatureController.isNotEmpty) {
      final bytes = await _techSignatureController.toPngBytes();
      if (bytes != null) {
        ref
            .read(maintenanceCompletionControllerProvider.notifier)
            .setTechnicianSignature(bytes);
      }
    }
  }

  Future<void> _saveCustomerSignature() async {
    if (_custSignatureController.isNotEmpty) {
      final bytes = await _custSignatureController.toPngBytes();
      if (bytes != null) {
        ref
            .read(maintenanceCompletionControllerProvider.notifier)
            .setCustomerSignature(bytes);
      }
    }
  }

  Future<void> _onStepContinue() async {
    final controller =
        ref.read(maintenanceCompletionControllerProvider.notifier);
    final step =
        ref.read(maintenanceCompletionControllerProvider).currentStep;

    // Capture signatures before moving away from their steps
    if (step == 2) await _saveTechSignature();
    if (step == 3) await _saveCustomerSignature();

    if (step < _totalSteps - 1) {
      controller.nextStep();
    } else {
      await _submit();
    }
  }

  void _onStepCancel() {
    final step =
        ref.read(maintenanceCompletionControllerProvider).currentStep;
    final controller =
        ref.read(maintenanceCompletionControllerProvider.notifier);
    if (step > 0) {
      controller.previousStep();
    } else {
      context.pop();
    }
  }

  Future<void> _submit() async {
    final controller =
        ref.read(maintenanceCompletionControllerProvider.notifier);
    controller.setNotes(_notesController.text);

    final success = await controller.submitMaintenance(
      widget.scheduleId,
      widget.elevatorId,
      widget.elevatorLocation,
    );

    if (!mounted) return;
    if (success) {
      _showSuccessBottomSheet();
    }
  }

  void _showSuccessBottomSheet() {
    final pdfFile =
        ref.read(maintenanceCompletionControllerProvider).generatedPdfFile;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'Bakım Tamamlandı!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rapor oluşturuldu ve sisteme kaydedildi.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Share PDF button
              if (pdfFile != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('PDF\'i Paylaş (WhatsApp / E-posta)'),
                    onPressed: () => _sharePdf(pdfFile),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.outline),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.pop();
                  },
                  child: const Text('Kapat'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sharePdf(File pdfFile) async {
    await Share.shareXFiles(
      [XFile(pdfFile.path, mimeType: 'application/pdf')],
      subject: 'Bakım Raporu - ${widget.elevatorLocation}',
      text:
          'Sayın Bina Yöneticisi, ${widget.elevatorLocation} adresindeki asansöre ait bakım raporunu ekte bulabilirsiniz.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceCompletionControllerProvider);
    final controller =
        ref.read(maintenanceCompletionControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bakım Tamamlama',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              widget.elevatorLocation,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
      body: state.isLoading
          ? _buildLoadingView()
          : Stepper(
              currentStep: state.currentStep,
              onStepContinue: _onStepContinue,
              onStepCancel: _onStepCancel,
              connectorColor:
                  WidgetStateProperty.resolveWith<Color>((states) {
                return states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.outline;
              }),
              controlsBuilder: (context, details) {
                final isLastStep =
                    state.currentStep == _totalSteps - 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: details.onStepContinue,
                        child: Text(
                            isLastStep ? 'Kaydet ve Tamamla' : 'Devam Et'),
                      ),
                      const SizedBox(width: 12),
                      if (state.currentStep > 0)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Geri',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                        ),
                    ],
                  ),
                );
              },
              steps: [
                // ── Step 0: Checklist ────────────────────────────────────
                Step(
                  title: const Text('Kontrol Listesi'),
                  isActive: state.currentStep >= 0,
                  state: state.currentStep > 0
                      ? StepState.complete
                      : StepState.indexed,
                  content: _buildChecklist(state, controller),
                ),
                // ── Step 1: Photos ────────────────────────────────────────
                Step(
                  title: const Text('Fotoğraflar'),
                  isActive: state.currentStep >= 1,
                  state: state.currentStep > 1
                      ? StepState.complete
                      : StepState.indexed,
                  content: _buildPhotos(state, controller),
                ),
                // ── Step 2: Technician Signature ──────────────────────────
                Step(
                  title: const Text('Teknisyen İmzası'),
                  isActive: state.currentStep >= 2,
                  state: state.currentStep > 2
                      ? StepState.complete
                      : StepState.indexed,
                  content: _buildSignaturePad(
                    label: 'Teknisyen olarak imzalayın',
                    controller: _techSignatureController,
                  ),
                ),
                // ── Step 3: Customer Signature ────────────────────────────
                Step(
                  title: const Text('Bina Yetkilisi İmzası'),
                  isActive: state.currentStep >= 3,
                  state: state.currentStep > 3
                      ? StepState.complete
                      : StepState.indexed,
                  content: _buildSignaturePad(
                    label: 'Bina yetkilisi olarak imzalayın',
                    controller: _custSignatureController,
                    accentColor: AppColors.warning,
                  ),
                ),
                // ── Step 4: Notes & Confirm ────────────────────────────────
                Step(
                  title: const Text('Notlar ve Onay'),
                  isActive: state.currentStep >= 4,
                  content: _buildNotesAndConfirm(state),
                ),
              ],
            ),
    );
  }

  // ── Loading View ─────────────────────────────────────────────────────────
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            'PDF raporu oluşturuluyor ve yükleniyor...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Checklist ─────────────────────────────────────────────────────────────
  Widget _buildChecklist(MaintenanceCompletionState state,
      MaintenanceCompletionController controller) {
    return Column(
      children: state.checklist.keys.map((key) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: CheckboxListTile(
            title:
                Text(key, style: const TextStyle(color: AppColors.textPrimary)),
            value: state.checklist[key],
            activeColor: AppColors.primary,
            checkColor: Colors.white,
            onChanged: (value) {
              if (value != null) controller.toggleChecklistItem(key, value);
            },
          ),
        );
      }).toList(),
    );
  }

  // ── Photos ────────────────────────────────────────────────────────────────
  Widget _buildPhotos(MaintenanceCompletionState state,
      MaintenanceCompletionController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _photoButton(
                icon: Icons.camera_alt_rounded,
                label: 'Kamera',
                onTap: () => _pickImage(ImageSource.camera)),
            const SizedBox(width: 10),
            _photoButton(
                icon: Icons.photo_library_rounded,
                label: 'Galeri',
                onTap: () => _pickImage(ImageSource.gallery)),
          ],
        ),
        const SizedBox(height: 16),
        if (state.photos.isNotEmpty)
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.photos.length,
              itemBuilder: (_, i) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(state.photos[i],
                            width: 100, height: 100, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => controller.removePhoto(state.photos[i]),
                        child: Container(
                          decoration: const BoxDecoration(
                              color: AppColors.error, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        else
          Text('Henüz fotoğraf eklenmedi.',
              style: TextStyle(color: AppColors.textMuted)),
      ],
    );
  }

  Widget _photoButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  // ── Signature Pad ─────────────────────────────────────────────────────────
  Widget _buildSignaturePad({
    required String label,
    required SignatureController controller,
    Color accentColor = AppColors.primary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: accentColor, width: 1.5),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Signature(
            controller: controller,
            height: 180,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => controller.clear(),
            icon: const Icon(Icons.refresh_rounded,
                size: 18, color: AppColors.textSecondary),
            label: const Text('Temizle',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }

  // ── Notes & Confirm ───────────────────────────────────────────────────────
  Widget _buildNotesAndConfirm(MaintenanceCompletionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _notesController,
          maxLines: 4,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Ek Notlar (İsteğe Bağlı)',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Summary card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            children: [
              _summaryRow(
                Icons.checklist_rounded,
                'Tamamlanan',
                '${state.checklist.values.where((v) => v).length}/${state.checklist.length} madde',
              ),
              const Divider(color: AppColors.outline, height: 16),
              _summaryRow(
                Icons.photo_library_rounded,
                'Fotoğraf',
                '${state.photos.length} adet',
              ),
              const Divider(color: AppColors.outline, height: 16),
              _summaryRow(
                Icons.draw_rounded,
                'Teknisyen İmzası',
                state.technicianSignatureBytes != null ? '✔ Alındı' : '✘ Yok',
                valueColor: state.technicianSignatureBytes != null
                    ? AppColors.success
                    : AppColors.error,
              ),
              const Divider(color: AppColors.outline, height: 16),
              _summaryRow(
                Icons.person_outline_rounded,
                'Bina Yetkilisi İmzası',
                state.customerSignatureBytes != null ? '✔ Alındı' : '✘ Yok',
                valueColor: state.customerSignatureBytes != null
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(state.errorMessage!,
                      style: const TextStyle(color: AppColors.onErrorContainer)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

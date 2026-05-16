import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/services/sync_queue_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/providers/connectivity_providers.dart';
import '../models/maintenance_log_model.dart';
import 'maintenance_providers.dart';

/// State object for the maintenance completion wizard.
class MaintenanceCompletionState {
  const MaintenanceCompletionState({
    this.currentStep = 0,
    this.checklist = const {
      'Kabin İçi Işıklandırma': false,
      'Kapı Sensörleri': false,
      'Fren Sistemleri': false,
      'Motor ve Ray Yağlama': false,
      'Kuyu Dibi Temizliği': false,
      'Acil Alarm ve Haberleşme': false,
    },
    this.photos = const [],
    this.technicianSignatureBytes,
    this.customerSignatureBytes,
    this.notes = '',
    this.isLoading = false,
    this.errorMessage,
    this.generatedPdfFile,
    this.pdfUrl,
  });

  final int currentStep;
  final Map<String, bool> checklist;
  final List<File> photos;

  /// Technician's own signature (captured on step 2).
  final List<int>? technicianSignatureBytes;

  /// Building representative's signature (captured on step 3).
  final List<int>? customerSignatureBytes;

  final String notes;
  final bool isLoading;
  final String? errorMessage;

  /// The locally-generated PDF file, ready for sharing.
  final File? generatedPdfFile;

  /// The Supabase Storage URL of the uploaded PDF (set after successful upload).
  final String? pdfUrl;

  MaintenanceCompletionState copyWith({
    int? currentStep,
    Map<String, bool>? checklist,
    List<File>? photos,
    List<int>? technicianSignatureBytes,
    List<int>? customerSignatureBytes,
    String? notes,
    bool? isLoading,
    String? errorMessage,
    File? generatedPdfFile,
    String? pdfUrl,
  }) {
    return MaintenanceCompletionState(
      currentStep: currentStep ?? this.currentStep,
      checklist: checklist ?? this.checklist,
      photos: photos ?? this.photos,
      technicianSignatureBytes:
          technicianSignatureBytes ?? this.technicianSignatureBytes,
      customerSignatureBytes:
          customerSignatureBytes ?? this.customerSignatureBytes,
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // always override (nullable)
      generatedPdfFile: generatedPdfFile ?? this.generatedPdfFile,
      pdfUrl: pdfUrl ?? this.pdfUrl,
    );
  }
}

class MaintenanceCompletionController
    extends AutoDisposeNotifier<MaintenanceCompletionState> {
  @override
  MaintenanceCompletionState build() {
    return const MaintenanceCompletionState();
  }

  // ── Step navigation ───────────────────────────────────────────────────────
  void nextStep() {
    if (state.currentStep < 4) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  // ── Checklist ─────────────────────────────────────────────────────────────
  void toggleChecklistItem(String key, bool value) {
    final updated = Map<String, bool>.from(state.checklist);
    updated[key] = value;
    state = state.copyWith(checklist: updated);
  }

  // ── Photos ────────────────────────────────────────────────────────────────
  void addPhoto(File photo) {
    state = state.copyWith(photos: [...state.photos, photo]);
  }

  void removePhoto(File photo) {
    state = state.copyWith(
      photos: state.photos.where((p) => p.path != photo.path).toList(),
    );
  }

  // ── Signatures ────────────────────────────────────────────────────────────
  void setTechnicianSignature(List<int> bytes) {
    state = state.copyWith(technicianSignatureBytes: bytes);
  }

  void setCustomerSignature(List<int> bytes) {
    state = state.copyWith(customerSignatureBytes: bytes);
  }

  // ── Legacy alias (kept for backward-compat with old usages) ──────────────
  void setSignature(List<int> bytes) => setTechnicianSignature(bytes);

  // ── Notes ─────────────────────────────────────────────────────────────────
  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  /// Submits the maintenance, generates the PDF, uploads everything, and
  /// saves to DB. Returns true on success.
  Future<bool> submitMaintenance(
    String scheduleId,
    String elevatorId,
    String elevatorLocation,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'Kullanıcı oturumu bulunamadı.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final storageService = ref.read(storageServiceProvider);
      final syncQueue = ref.read(syncQueueServiceProvider);
      final pdfService = PdfService();

      // 1. Resolve technician name
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));
      final technicianName =
          (profileResponse?['full_name'] as String?) ?? 'Teknisyen';

      // 2. Connectivity check
      bool isOnline = true;
      try {
        await Supabase.instance.client
            .from('profiles')
            .select('id')
            .limit(1)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        isOnline = false;
      }

      // 3. Generate PDF locally (always — needed for share button)
      final techSigBytes = state.technicianSignatureBytes != null
          ? Uint8List.fromList(state.technicianSignatureBytes!)
          : null;
      final custSigBytes = state.customerSignatureBytes != null
          ? Uint8List.fromList(state.customerSignatureBytes!)
          : null;

      final pdfFile = await pdfService.generateMaintenanceReport(
        elevatorId: elevatorId,
        elevatorLocation: elevatorLocation,
        technicianName: technicianName,
        maintenanceDate: DateTime.now().toUtc(),
        checklist: state.checklist,
        notes: state.notes,
        technicianSignatureBytes: techSigBytes,
        customerSignatureBytes: custSigBytes,
      );

      // Store the generated file so the UI can offer a Share button
      state = state.copyWith(generatedPdfFile: pdfFile);

      if (isOnline) {
        // ── ONLINE FLOW ──────────────────────────────────────────────────
        List<String> uploadedPhotos = [];
        String? technicianSigUrl;
        String? customerSigUrl;
        String? pdfUrl;

        // 4a. Upload photos
        for (final photo in state.photos) {
          final url = await storageService.uploadImage(
            photo,
            'photos/$scheduleId',
            bucketName: 'maintenance-records',
          );
          uploadedPhotos.add(url);
        }

        // 4b. Upload technician signature
        if (state.technicianSignatureBytes != null) {
          technicianSigUrl = await storageService.uploadBytes(
            state.technicianSignatureBytes!,
            'signatures/$scheduleId/tech_${const Uuid().v4()}.png',
            bucketName: 'maintenance-records',
            contentType: 'image/png',
          );
        }

        // 4c. Upload customer/building-rep signature
        if (state.customerSignatureBytes != null) {
          customerSigUrl = await storageService.uploadBytes(
            state.customerSignatureBytes!,
            'signatures/$scheduleId/customer_${const Uuid().v4()}.png',
            bucketName: 'maintenance-records',
            contentType: 'image/png',
          );
        }

        // 4d. Upload PDF to maintenance_reports bucket
        final pdfBytes = await pdfFile.readAsBytes();
        pdfUrl = await storageService.uploadBytes(
          pdfBytes,
          'reports/$scheduleId/${const Uuid().v4()}.pdf',
          bucketName: 'maintenance-reports',
          contentType: 'application/pdf',
        );
        state = state.copyWith(pdfUrl: pdfUrl);

        // 5. Build model and save to DB
        final logModel = MaintenanceLogModel(
          id: const Uuid().v4(),
          elevatorId: elevatorId,
          technicianId: user.id,
          notes: state.notes,
          isApproved: false,
          maintenanceDate: DateTime.now().toUtc(),
          checklist: state.checklist,
          photos: uploadedPhotos,
          signatureUrl: technicianSigUrl,
          pdfUrl: pdfUrl,
          customerSignatureUrl: customerSigUrl,
        );

        final repository = ref.read(maintenanceRepositoryProvider);
        await repository.completeMaintenance(scheduleId, logModel);

        // 6. Notify admins
        NotificationService.instance.notifyAllAdmins(
          client: Supabase.instance.client,
          title: 'Bakım Görevi Tamamlandı',
          body: 'Bir teknisyen saha görevini tamamladı.',
          data: {
            'type': 'task_completed',
            'schedule_id': scheduleId,
            'elevator_id': elevatorId,
            'route': '/admin/master-calendar',
          },
        );
      } else {
        // ── OFFLINE FLOW ─────────────────────────────────────────────────
        // Store local file paths so media uploads can resume safely later.
        final localMediaPaths = <String>[];
        final mediaFields = <String>[];

        if (state.photos.isNotEmpty) {
          for (final photo in state.photos) {
            localMediaPaths.add(photo.path);
            mediaFields.add('photos');
          }
        }

        final technicianSigPath = await _writeTempSignature(
          state.technicianSignatureBytes,
          'tech_sig',
        );
        if (technicianSigPath != null) {
          localMediaPaths.add(technicianSigPath);
          mediaFields.add('signature_url');
        }

        final customerSigPath = await _writeTempSignature(
          state.customerSignatureBytes,
          'cust_sig',
        );
        if (customerSigPath != null) {
          localMediaPaths.add(customerSigPath);
          mediaFields.add('customer_signature_url');
        }

        if (await pdfFile.exists()) {
          localMediaPaths.add(pdfFile.path);
          mediaFields.add('pdf_url');
        }

        final payload = {
          'id': const Uuid().v4(),
          'elevator_id': elevatorId,
          'technician_id': user.id,
          'notes': state.notes,
          'is_approved': false,
          'maintenance_date': DateTime.now().toUtc().toIso8601String(),
          'checklist': state.checklist,
          '_schedule_id': scheduleId,
          if (mediaFields.isNotEmpty) '_media_fields': mediaFields,
          if (mediaFields.isNotEmpty) '_media_list_fields': const ['photos'],
        };

        await syncQueue.enqueue(
          endpoint: SyncEndpoint.insertMaintenanceLog,
          payload: payload,
          localMediaPaths: localMediaPaths,
        );
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<String?> _writeTempSignature(List<int>? bytes, String prefix) async {
    if (bytes == null || bytes.isEmpty) return null;
    final file = File(
      '${Directory.systemTemp.path}/${prefix}_${const Uuid().v4()}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

final maintenanceCompletionControllerProvider =
    NotifierProvider.autoDispose<
      MaintenanceCompletionController,
      MaintenanceCompletionState
    >(() => MaintenanceCompletionController());
